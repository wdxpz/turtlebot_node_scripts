# 1. Launch single robot at boot on turtlebot node

## Preparation: update firewaree and software on turtlebot

refer to [section 3 How to update](https://discourse.ros.org/t/announcing-turtlebot3-software-v1-0-0-and-firmware-v1-2-0-update/4888)

## Autostart by robot_upstart 

### Tutorial

1. refer to [make a roslaunch start on boot (robot_upstart)](https://roboticsbackend.com/make-ros-launch-start-on-boot-with-robot_upstart/) or [local file](docs/make roslaunch start at boot (robot_upstart).pdf)
2. [robot_upstart wiki](https://wiki.ros.org/robot_upstart)

### Shell commands

1. auto start turtlebot3 at boot on turtlebot

   ```
   $ rosrun robot_upstart install turtlebot3_bringup/launch/turtlebot3_robot.launch --job start_robot --user waffle --interface wlan0 --master http://192.168.3.89:11311 --logdir /home/waffle/logs --symlink
   $ sudo systemctl daemon-reload
   $ sudo systemctl start start_robot
   ```


## Autostart by systemd service (works for single robot, not multiple robot)

1.  refer to [Autostart service after system boot](https://risc.readthedocs.io/2-auto-service-start-afer-boot.html)

2. edit sh to run roslaunch robot

   ```
   #!/bin/bash
   machine_ip=('hostname -I')
   export ROS_IP=${machine_ip[0]}
   
   export ROS_HOSTNAME=192.168.3.90
   
   export ROS_MASTER_URI=http://192.168.3.89:11311
   
   export TURTLEBOT3_MODEL=waffle_pi
   
   source /opt/ros/kinetic/setup.bash
   source /home/waffle/catkin_ws/devel/setup.sh
   
   roslaunch turtlebot3_bringup turtlebot3_robot.launch
   ```

3. deploy service to start robot at boot

   ```
   [Unit]
   Description=Auto-start Robot Service
   
   [Service]
   Type=idle
   User=waffle
   Group=waffle
   ExecStart=/home/waffle/start_robot/startup_launch.sh
   Restart=on-failure
   RestartSec=10
   
   [Install]
   WantedBy=multi-user.target
   ```

# 2. Multirobot Model Launch

## [video tutourial and demo project](https://www.theconstructsim.com/zh-hans/ros-qa-130-how-to-launch-multiple-robots-in-gazebo-simulator/)

## manually launch each turtlebot node

   ```
   $ ROS_NAMESPACE=tb3_0 roslaunch turtlebot3_bringup turtlebot3_robot.launch multi_robot_name:="tb3_0" set_lidar_frame_id:="tb3_0/base_scan"
   ```

   which will add ros nodes:

   ```
   /tb3_0/turtlebot3_core
   /tb3_0/turtlebot3_diagnostics
   /tb3_0/turtlebot3_lds
   ```

## auto launch each trutlebot node by robot_startup rospackage
### make startrobot service
   1. create  or copy ros project `launch_robot` under `~/catkin_ws/src/`

     ```
     $ catkin_create_pkg launch_robot
     $ mkdir launch
     $ nano launch_robot_with_name.launch
     
     #edit launch_robot_with_name.launch
     <?xml version="1.0"?>
     <launch>
       <include file="$(find turtlebot3_bringup)/launch/turtlebot3_robot.launch">          
       <arg name="multi_robot_name" value="$(env ROS_NAMESPACE)" />
       <arg name="set_lidar_frame_id" value="$(env ROS_NAMESPACE)/base_scan" />
       </include>
     </launch>
     ```
    
     **NOTE: it is crisis to set ROS_NAMESPACE in /usr/sbin/start_robot-start**

   2. create robot_upstart job

     ```
     $ rosrun robot_upstart install launch_robot/launch/launch_robot_with_name.launch --job startrobot --user waffle --interface wlan0 --master http://192.168.3.89:11311 --logdir /home/waffle/logs --symlink
     ```


​     

   3. `sudo nano /usr/sbin/startrobot-start`

     see [startrobot-start](startrobot-start)
    
     ```
     #add or modify after:
     export ROS_MASTER_URI=http://192.168.3.89:11311
     export ROS_HOME=${ROS_HOME:=$(echo ~waffle)/.ros}
     export ROS_LOG_DIR=$log_path
     export ROS_HOSTNAME=192.168.3.90
     export ROS_NAMESPACE="tb3_0"
     export ROS_IP=192.168.3.90
     
     #add para --wait in the line:
     # Punch it.
     setuidgid waffle roslaunch --wait &LAUNCH_FILENAME &
     PID=$!
     ```

   4. `sudo nano /lib/systemd/system/startrobot.service`

     ```
     [Unit]
     Description="bringup startrobot"
     After=network.target
    
     [Service]
     Type=idle
     ExecStartPre=/bin/sleep 60 
     ExecStart=/usr/sbin/startrobot-start
    
     [Install]
     WantedBy=multi-user.target
     ```

   5. sudo systemctl daemon-reload && sudo systemctl start startrobot`

### make monitor service to reboot startrobot service if failed

   1. create or copy [monitor scripts](monitor.sh)

   2. create or copy [monitor.service](monitor.service)

   3. enalbe and start it

   ```
   cp monitor.service /lib/systemd/system/monitor.service
   sudo systemctl daemon-reload
   sudo systemctl enable monitor.service
   sudo systemctl start monitor.service
   ```

### monitor service ouput
```
sudo journalctl -e -u monitor.service
```
## auto launch each rosbot node by robot_startup rospackage
### make startrobot service
   1. create  or copy ros project `launch_robot` under `~/ros_workspace/src/`

     ```
     catkin_create_pkg launch_rosbot
     roscd launch_rosbot
     cp -r repository/launch_rosbot/* .
     
     #launch_rosbot_with_name.launch
    <?xml version="1.0"?>
     <launch>
       <include file="$(find launch_rosbot)/launch/start_namesapce.launch">          
         <arg name="robot_namespace" value="rosbot1" />
       </include>
     </launch>
     ```
    
     **NOTE: no need to set ROS_NAME in /usr/sbin/start_robot-start**
     **NOTE: by this luanch_rosbot_with_name.launch, lidar, amcl and movebase will be launched locally. In robotcontroller service at master node side, only need to start map_server, like start_rosbot_only_map.launch** 

   2. create robot_upstart job

     ```
     $ rosrun robot_upstart install launch_rosbot/launch/launch_rosbot_with_name.launch --job startrobot --user husarion --interface wlan0 --master http://192.168.3.89:11311 --logdir /home/husarion/logs --symlink
     ```

   3. `sudo nano /usr/sbin/startrobot-start`

      see [startrobot-start.rosbot](startrobot-start.rosbot)

    #add or modify after:
    log_path="/home/husarion/logs"
    
    export ROS_IP=`rosrun robot_upstart getifip wlx70f11c32f38a`
    
    export ROS_MASTER_URI=http://192.168.3.118:11311
    export ROS_HOME=${ROS_HOME:=$(echo ~husarion)/.ros}
    export ROS_LOG_DIR=$log_path
    export ROS_HOSTNAME=192.168.3.154
    #export ROS_NAME="rosbot1" ###remember not ROS_NAMESPACE
    export ROS_IP=192.168.3.154
    chmod 666 /dev/ttyS4 ###critical to open the access right
    
     
     #add para --wait in the line:
     # Punch it.
     setuidgid waffle roslaunch --wait &LAUNCH_FILENAME &
     PID=$!
     ```

   4. `sudo nano /lib/systemd/system/startrobot.service`

      see [startrobot.service.rosbot](startrobot.service.rosbot)

    [Unit]
    Description="bringup startrobot"
    After=network.target
    
    [Service]
    Type=idle
    ExecStartPre=/bin/sleep 10
    ExecStart=/usr/sbin/startrobot-start
    
    [Install]
    WantedBy=multi-user.target

   5. sudo systemctl daemon-reload && sudo systemctl start startrobot`

### stop lipradar motor

```
rosservice call /rosbot1/stop_motor
```



