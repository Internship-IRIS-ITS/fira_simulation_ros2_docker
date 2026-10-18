cmake_minimum_required(VERSION 3.0.2)
project(iris_fira_simulation)

find_package(catkin REQUIRED COMPONENTS
  rospy
  std_msgs
)

catkin_package(
  CATKIN_DEPENDS rospy std_msgs
)

catkin_install_python(PROGRAMS
                        scripts/diffdrive2gazebo.py
                        scripts/ackermann2gazebo.py
                        scripts/ackermann2gazebo_udp.py
                      DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION})
