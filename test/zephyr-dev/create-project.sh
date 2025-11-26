#!/usr/bin/env bash

# Create project structure
mkdir -p zephyr_blinky_project/app/src
cd zephyr_blinky_project || exit 1

# Create minimal main.c
cat > app/src/main.c << 'EOF'
 #include <stdio.h>
 #include <zephyr/kernel.h>
 #include <zephyr/drivers/gpio.h>
 
 /* 1000 msec = 1 sec */
 #define SLEEP_TIME_MS   1000
 
 /* The devicetree node identifier for the "led0" alias. */
 #define LED0_NODE DT_ALIAS(led0)
 
 /*
  * A build error on this line means your board is unsupported.
  * See the sample documentation for information on how to fix this.
  */
 static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);
 
 int main(void)
 {
     int ret;
     bool led_state = true;
 
     if (!gpio_is_ready_dt(&led)) {
         return 0;
     }
 
     ret = gpio_pin_configure_dt(&led, GPIO_OUTPUT_ACTIVE);
     if (ret < 0) {
         return 0;
     }
 
     while (1) {
         ret = gpio_pin_toggle_dt(&led);
         if (ret < 0) {
             return 0;
         }
 
         led_state = !led_state;
         printf("LED state: %s\n", led_state ? "ON" : "OFF");
         k_msleep(SLEEP_TIME_MS);
     }
     return 0;
 }
EOF

# Create minimal CMakeLists.txt
cat > app/CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.20.0)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(blinky)

target_sources(app PRIVATE src/main.c)
EOF

# Create project config
cat > app/prj.conf << 'EOF'
CONFIG_GPIO=y
EOF

# Create west manifest
cat > app/west.yml << 'EOF'
manifest:

  projects:
    - name: zephyr
      url: https://github.com/zephyrproject-rtos/zephyr
      revision: v4.3.0
      import: true
EOF

# create west config
mkdir .west
cat > .west/config << 'EOF'
[manifest]
path = app
file = west.yml

[zephyr]
base = zephyr
EOF