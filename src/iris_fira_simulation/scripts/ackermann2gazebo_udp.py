#!/usr/bin/env python
#
# UDP version of ackermann2gazebo.py. Instead of subscribing to
# /catvehicle/ackermann_vel, this node listens on a UDP port for
# datagrams carrying an Ackermann steering velocity command and forwards
# it to the ROS topics exposed in Gazebo for driving catvehicle.
#
# Packet layout (12 bytes, all integers little-endian):
#   offset 0: header, 4 bytes, ASCII "IRIS"
#   offset 4: linear velocity, 1 x int32; motor PWM clamped to
#             [-255, 255], sets the rear wheel speed, scaled to the
#             rad/s expected by Gazebo's joint velocity controllers via
#             ~max_rpm (the wheel RPM at full-scale PWM) and an optional
#             ~gain for a gearbox or other mechanical reduction
#   offset 8: steering angle, 1 x int32 (in degrees); sets the front
#             wheel angle directly, with no clamping, so the caller is
#             responsible for keeping it within a sane range

import rospy
from std_msgs.msg import Float64
import math
import socket
import struct
import threading

HEADER = b'IRIS'
PACKET_FMT = '<4sii'  # header, linear velocity (motor pwm), steering angle (deg)
PACKET_SIZE = struct.calcsize(PACKET_FMT)


class ackermann2gazebo_udp:

    def __init__(self):
        rospy.init_node('ackermann2gazebo_udp', anonymous=True)

        self.pub_rearL = rospy.Publisher('/catvehicle/joint1_velocity_controller/command', Float64, queue_size=1)
        self.pub_rearR = rospy.Publisher('/catvehicle/joint2_velocity_controller/command', Float64, queue_size=1)
        self.pub_steerL = rospy.Publisher('/catvehicle/front_left_steering_position_controller/command', Float64, queue_size=1)
        self.pub_steerR = rospy.Publisher('/catvehicle/front_right_steering_position_controller/command', Float64, queue_size=1)

        # initial target rear wheel velocity (rad/s) and steering angle (rad)
        self.vel = 0.0
        self.steer = 0.0

        # wheel RPM at full-scale (255) motor_pwm
        self.max_rpm = rospy.get_param('~max_rpm', 100.0)

        # gain to account for a gearbox/mechanical reduction between the
        # commanded PWM and the joint's actual angular velocity; tune with
        # the ~gain param if the simulated wheel speed doesn't match the
        # commanded PWM
        self.gain = rospy.get_param('~gain', 1.0)

        # how many seconds delay for the dead man's switch
        self.timeout = rospy.Duration.from_sec(rospy.get_param('~timeout', 0.2))
        self.lastMsg = None

        # whether we're currently asserting commands onto the shared
        # rear-wheel/steering topics; starts false (no message yet) so we
        # don't fight cmdvel2gazebo/diffdrive2gazebo before anyone has
        # actually commanded this node
        self.active = False

        self.lock = threading.Lock()

        # UDP server: bind on ~port and spawn a listener
        # thread so packethandling never blocks the 100Hz publish loop
        self.udp_port = rospy.get_param('~port', 12151)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        # self.sock.bind(('0.0.0.0', self.udp_port))
        self.sock.bind(('127.0.0.1', self.udp_port))
        rospy.loginfo('ackermann2gazebo_udp listening on UDP port %d', self.udp_port)
        self.listener = threading.Thread(target=self.listen_loop)
        self.listener.daemon = True
        self.listener.start()

    def listen_loop(self):
        # Busy loop for the UDP socket; the timeout on the socket lets us
        # unthread cleanly if the node is killed
        self.sock.settimeout(1.0)
        while not rospy.is_shutdown():
            try:
                data, addr = self.sock.recvfrom(1024)
            except socket.timeout:
                continue
            self.handle_packet(data)

    def handle_packet(self, data):
        # data is [motor_pwm, steering_angle]; motor_pwm is clamped to
        # [-255, 255] and converted to rad/s, steering_angle (degrees) is
        # converted to radians with no clamping
        try:
            header, motor_pwm_raw, steer_raw = struct.unpack(PACKET_FMT, data[:PACKET_SIZE])
        except struct.error:
            rospy.logwarn_throttle(10, 'malformed UDP packet: got %d bytes, expected %d', len(data), PACKET_SIZE)
            return

        if header != HEADER:
            rospy.logwarn_throttle(10, 'bad header %r, expected %r', header, HEADER)
            return

        motor_pwm = max(-255, min(255, motor_pwm_raw))
        with self.lock:
            self.vel = self.gain*(motor_pwm/255.0)*self.max_rpm*2.0*math.pi/60.0
            self.steer = math.radians(-steer_raw)
            self.lastMsg = rospy.Time.now()
            self.active = True

    def publish(self):
        with self.lock:
            if self.lastMsg is None:
                # never received a command; stay silent so we don't fight
                # whichever other node is actually driving the vehicle
                return

            if rospy.Time.now() - self.lastMsg > self.timeout:
                if not self.active:
                    # already idle; stay silent and yield the shared topics
                    return
                # just went idle: publish one final stop (steering left
                # unchanged, matching cmdvel2gazebo's behavior), then go silent
                self.vel = 0.0
                self.active = False

            msgRear = Float64()
            msgRear.data = self.vel
            self.pub_rearL.publish(msgRear)
            self.pub_rearR.publish(msgRear)

            msgSteer = Float64()
            msgSteer.data = self.steer
            self.pub_steerL.publish(msgSteer)
            self.pub_steerR.publish(msgSteer)


def main():
    node = ackermann2gazebo_udp()
    rate = rospy.Rate(100, reset=True) # run at 100Hz; reset=True so a Gazebo reload (sim clock jumping backwards) doesn't kill this node
    while not rospy.is_shutdown():
        node.publish()
        rate.sleep()

if __name__ == '__main__':
    try:
        main()
    except rospy.ROSInterruptException:
        pass
