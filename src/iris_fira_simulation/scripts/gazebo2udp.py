#!/usr/bin/env python
#
# UDP telemetry sender: the reverse of ackermann2gazebo_udp.py. Instead of
# listening on a UDP port, this node subscribes to the vehicle's sensor
# topics in Gazebo and continuously streams them as datagrams to a
# remote endpoint, so an external client can read the vehicle state as
# if it came from a real car's sensors.
#
# Packet layout (20 bytes, all integers little-endian):
#   offset 0:  header, 4 bytes, ASCII "IRIS"
#   offset 4:  left wheel encoder, 1 x int32; cumulative tick count,
#              simulated from the back_left_wheel_joint angle via
#              ~ticks_per_rev
#   offset 8:  right wheel encoder, 1 x int32; same for
#              back_right_wheel_joint
#   offset 12: car forward (X) velocity, 1 x int32; body-frame
#              twist.linear.x from odometry, scaled to cm/s via ~vel_scale
#   offset 16: car left-right (Y) velocity, 1 x int32; body-frame
#              twist.linear.y, same scaling

import rospy
from sensor_msgs.msg import JointState
from nav_msgs.msg import Odometry
import math
import socket
import struct
import threading

HEADER = b'IRIS'
PACKET_FMT = '<4siiii'  # header, left ticks, right ticks, vx (cm/s), vy (cm/s)
PACKET_SIZE = struct.calcsize(PACKET_FMT)

LEFT_WHEEL_JOINT = 'back_left_wheel_joint'
RIGHT_WHEEL_JOINT = 'back_right_wheel_joint'


class gazebo2udp:

    def __init__(self):
        rospy.init_node('gazebo2udp', anonymous=True)

        # tick count at one full wheel revolution, i.e. the simulated
        # encoder resolution
        self.ticks_per_rev = rospy.get_param('~ticks_per_rev', 1024)

        # multiplier converting odom m/s into the integer payload unit;
        # 100.0 sends centimeters per second
        self.vel_scale = rospy.get_param('~vel_scale', 100.0)

        # latest sensor values, shared between subscriber callbacks and
        # the sender thread, guarded by a lock
        self.lock = threading.Lock()
        self.left_ticks = 0
        self.right_ticks = 0
        self.vel_x = 0
        self.vel_y = 0

        # we stay silent until every source has delivered at least one
        # message, so we never transmit garbage before Gazebo is up
        self.have_encoders = False
        self.have_odom = False

        rospy.Subscriber('/catvehicle/joint_states', JointState, self.joint_states_cb)
        rospy.Subscriber('/catvehicle/odom', Odometry, self.odom_cb)

        # UDP client: fire-and-forget datagrams to ~host:~port
        self.udp_host = rospy.get_param('~host', '127.0.0.1')
        self.udp_port = rospy.get_param('~port', 12152)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        rospy.loginfo('gazebo2udp sending telemetry to %s:%d at %d Hz',
                      self.udp_host, self.udp_port, rospy.get_param('~rate', 100))

        self.rate = rospy.Rate(rospy.get_param('~rate', 100), reset=True) # reset=True so a Gazebo reload (sim clock jumping backwards) doesn't kill this node

    def joint_states_cb(self, msg):
        # look the wheels up by name so a change in joint_states ordering
        # can't silently swap left/right
        try:
            left_pos = msg.position[msg.name.index(LEFT_WHEEL_JOINT)]
            right_pos = msg.position[msg.name.index(RIGHT_WHEEL_JOINT)]
        except ValueError:
            rospy.logwarn_throttle(10, 'wheel joints %s/%s not found in joint_states',
                                   LEFT_WHEEL_JOINT, RIGHT_WHEEL_JOINT)
            return

        # continuous joints accumulate angle without wrapping, so the
        # tick count grows monotonically in one direction like a real
        # quadrature encoder
        left_ticks = int(round(left_pos/(2.0*math.pi)*self.ticks_per_rev))
        right_ticks = int(round(right_pos/(2.0*math.pi)*self.ticks_per_rev))
        with self.lock:
            self.left_ticks = left_ticks
            self.right_ticks = right_ticks
            self.have_encoders = True

    def odom_cb(self, msg):
        # twist is in the child frame (base_link), i.e. body-frame forward
        # (x) and lateral (y) velocity
        vx = int(round(msg.twist.twist.linear.x*self.vel_scale))
        vy = int(round(msg.twist.twist.linear.y*self.vel_scale))
        with self.lock:
            self.vel_x = vx
            self.vel_y = vy
            self.have_odom = True

    def send(self):
        with self.lock:
            if not (self.have_encoders and self.have_odom):
                # Gazebo not up yet (or topics not connected); emit nothing
                # rather than a packet of zeros
                return
            packet = struct.pack(PACKET_FMT, HEADER,
                                 self.left_ticks, self.right_ticks,
                                 self.vel_x, self.vel_y)
        self.sock.sendto(packet, (self.udp_host, self.udp_port))

    def spin(self):
        while not rospy.is_shutdown():
            self.send()
            self.rate.sleep()


def main():
    node = gazebo2udp()
    node.spin()

if __name__ == '__main__':
    try:
        main()
    except rospy.ROSInterruptException:
        pass
