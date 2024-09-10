
import QtQuick 2.7
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import Vedder.vesc.vescinterface 1.0
import Vedder.vesc.esp32flash 1.0
import Vedder.vesc.utility 1.0
import Vedder.vesc.codeloader 1.0
import Vedder.vesc.syscmd 1.0

Item {
    id: mainItem
    anchors.fill: parent

    // TODO: Adjust for vesc-os
    property string filesLocation: "/Firmware/"
    //property string filesLocation: "/home/renee/LIND/Firmware/build/"

    // ESP Pins to RPi GPIO (gpiochip0)
    property string espEn: "5"
    property string espGpio9: "6"
    property string espGpio2: "12"

    // STM32 Pins to RPi GPIO (gpiochip0)
    property string stmReset: "18"
    property string stmSwdio: "24"
    property string stmSwclk: "25"

    Esp32Flash {
        id: flasher
        onFlashProgress: {
            progressBarValue = prog
        }
        onStateUpdate: {
            logToConsoles("ESP Status: " + arguments[0])
        }
    }

    SysCmd {
        id: syscmd
        onProcessOutput: {
            logToConsoles("Process Output: " + arguments[0])
        }
    }

    CodeLoader {
        id: mLoader
        Component.onCompleted: {
            mLoader.setVesc(VescIf)
        }
    }

    property double progressBarValue: 0

    property var parentTabBar: parent.tabBarItem
    property string consoleOutput: ""
    onConsoleOutputChanged: scrollTimer.restart()

    Component.onCompleted: {
        parentTabBar.visible = true
        parentTabBar.enabled = true
    }

    TabBar {
        id: localTabBar
        parent: parentTabBar
        anchors.fill: parent
        currentIndex: swipeView.currentIndex

        background: Rectangle {
            opacity: 1
            color: Utility.getAppHexColor("lightBackground")
        }

        property int buttonWidth: Math.max(150, localTabBar.width / (rep.model.length))

        Repeater {
            id: rep
            model: ["Programming", "Testing"]

            TabButton {
                text: modelData
                width: localTabBar.buttonWidth
            }
        }
    }

    SwipeView {
        id: swipeView
        currentIndex: localTabBar.currentIndex
        anchors.fill: parent
        clip: true

        Page {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 10

                GridLayout {
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10
                    width: parent.width

                    Button { text: "remote-disp-esp"; Layout.fillWidth: true; onClicked: handleButtonClick(text, true) }
                    Button { text: "bat-ant-esp"; Layout.fillWidth: true; onClicked: handleButtonClick(text, true) }
                    Button { text: "bat-bms-esp"; Layout.fillWidth: true; onClicked: handleButtonClick(text, true) }
                    Button { text: "jet-if-esp"; Layout.fillWidth: true; onClicked: handleButtonClick(text, true) }
                    Button { text: "bat-ant-stm"; Layout.fillWidth: true; onClicked: handleButtonClick(text, false) }
                    Button { text: "bat-bms-stm"; Layout.fillWidth: true; onClicked: handleButtonClick(text, false) }
                    Button { text: "bat-esc-stm"; Layout.fillWidth: true; onClicked: handleButtonClick(text, false) }
                    Button { text: "charger-esp"; Layout.fillWidth: true; onClicked: handleButtonClick(text, true) }
                }

                RowLayout {
                    width: parent.width
                    spacing: 5

                    Text {
                        text: "Progress: "
                        color: "white"
                        verticalAlignment: Text.AlignVCenter
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    }

                    ProgressBar {
                        id: progressBar
                        width: Layout.fillWidth
                        height: 40
                        value: progressBarValue
                        Layout.fillWidth: true
                    }
                }

                Flickable {
                    id: flickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: consoleTextArea.width
                    contentHeight: consoleTextArea.height
                    clip: true

                    TextArea {
                        id: consoleTextArea
                        width: flickable.width
                        height: Math.max(flickable.height, implicitHeight)
                        text: mainItem.consoleOutput
                        readOnly: true
                        wrapMode: TextArea.Wrap
                        color: "black"
                        background: Rectangle {
                            color: "white"
                        }
                    }

                    ScrollBar.vertical: ScrollBar {}
                }
            }

            // Floating logo
            Image {
                source: "file:///logo.png"
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 300
                anchors.rightMargin: 15
            }
        }

        Page {
            Text {
                anchors.fill: parent
                anchors.margins: 5
                text: "Tab 2"
                color: "white"
            }
        }
    }

    /* First Tab "Programming" support objects and functions */

    Timer {
        id: scrollTimer
        interval: 50
        onTriggered: {
            flickable.contentY = flickable.contentHeight - flickable.height
        }
    }

    Timer {
        id: delayTimer
    }

    Timer {
        id: delayTimer2
    }

    function delay(delayTime, cb) {
        delayTimer.interval = delayTime;
        delayTimer.repeat = false;
        delayTimer.triggered.connect(cb);
        delayTimer.start();
    }

    function delay2(delayTime, cb) {
        delayTimer2.interval = delayTime;
        delayTimer2.repeat = false;
        delayTimer2.triggered.connect(cb);
        delayTimer2.start();
    }

    function busyWait(milliseconds) {
        var start = new Date().getTime();
        var end = start;
        while (end < start + milliseconds) {
            end = new Date().getTime();
        }
    }

    function logToConsoles(logMessage) {
        console.log(logMessage)
        mainItem.consoleOutput += logMessage + "\n"
    }

    property string deviceName: ""
    property bool lisp_install_result: false
    signal lispInstalledSignal()
    function waitForSignal(signal) {
        return new Promise((resolve) => {
            signal.connect(() => {
                resolve();
            });
        });
    }

    function flashEsp32Lisp() {
        logToConsoles("Installing Lisp Package")
        lisp_install_result = false

        VescIf.connectSerial("/dev/ttyACM0", 115200)

        // Wait for connect operations to finish or there will be consequences
        delay2(2000, function() {
            var fname_lisp = filesLocation + deviceName + "/lisp.vescpkg"

            lisp_install_result = mLoader.installVescPackageFromPath(fname_lisp)
            VescIf.disconnectPort()

            lispInstalledSignal()
        })

        //await waitForSignal(lispInstalledSignal)
        waitForSignal(lispInstalledSignal).then(() => {
            if (lisp_install_result) {
                logToConsoles("Flashing completed successfully on " + deviceName)
            } else {
                logToConsoles("Flashing failed on " + deviceName)
            }

            unlockInstallDevice()
        });
    }

    function resetEsp () {
        // Toggle ESP_EN after setting GPIO 9 low
        syscmd.executeCommand("gpioset gpiochip0 " + espEn + "=0")
        busyWait(250) // Wait a few milliseconds
        syscmd.executeCommand("gpioset gpiochip0 " + espEn + "=1")
        busyWait(1000) // Wait a few milliseconds
    }

    function flashEsp32Firmware() {
        // Set GPIO 9 low for entering bootloader
        syscmd.executeCommand("gpioset gpiochip0 " + espGpio9 + "=0")
        resetEsp()

        var flash_result = false

        var offset_bl = 0x0
        var offset_part = 0x8000
        var offset_fw = 0x20000

        var fname_bl = filesLocation + deviceName + "/bootloader.bin"
        var fname_part = filesLocation + deviceName + "/partition-table.bin"
        var fname_fw = filesLocation + deviceName + "/firmware.bin"

        flash_result = flasher.connectEsp("/dev/ttyACM0")
        if (!flash_result) {
            logToConsoles("Error connecting to " + deviceName)
        }

        if (flash_result) {
            var file_bl = Utility.readAllFromFile(fname_bl)
            flash_result = flasher.flashFirmware(file_bl, offset_bl)
            logToConsoles("Bootloader Flashed: " + flash_result)
        }

        if (flash_result) {
            var file_part = Utility.readAllFromFile(fname_part)
            flash_result = flasher.flashFirmware(file_part, offset_part)
            logToConsoles("Partition Table Flashed: " + flash_result)
        }

        if (flash_result) {
            var file_fw = Utility.readAllFromFile(fname_fw)
            flash_result = flasher.flashFirmware(file_fw, offset_fw)
            logToConsoles("Firmware Flashed: " + flash_result)
        }

        flasher.disconnectEsp()

        // Set GPIO 9 to an input to restore normal operation
        syscmd.executeCommand("gpioget gpiochip0 " + espGpio9)
        resetEsp()

        if (flash_result) {
            logToConsoles("Preparing to install Lisp Package")
            delay(2000, function() {
                flashEsp32Lisp()
            })
        } else {
            logToConsoles("Flashing failed on " + deviceName)
            unlockInstallDevice()
        }
    }

    function lockInstallDevice(device) {
        deviceName = device
    }

    function unlockInstallDevice() {
        deviceName = ""
    }

    function isInstallDeviceLocked() {
        return deviceName != ""
    }

    function handleButtonClick(device, isEsp32) {
        if (isInstallDeviceLocked()) {
            logToConsoles("Please wait for " + deviceName + " to finish flashing")
            return false
        }

        if (isEsp32) {
            lockInstallDevice(device)
            logToConsoles("Flashing ESP32 Device: " + deviceName)
            flashEsp32Firmware()
        } else {
            lockInstallDevice(device)
            logToConsoles("Flashing STM32 Device: " + deviceName)

            var configFile = ""

            if (deviceName == "bat-ant-stm") {
                // NOTE: STM32G431
                configFile = "/Firmware/openocd-pi-stm32g4.cfg"
            } else if (deviceName == "bat-bms-stm") {
                // NOTE: STM32L4
                configFile = "/Firmware/openocd-pi-stm32l4.cfg"
            } else if (deviceName == "bat-esc-stm") {
                // NOTE: STM32F4
                configFile = "/Firmware/openocd-pi-stm32f4.cfg"
            } else {
                logToConsoles("Error: Invalid STM Device")
            }
            syscmd.executeCommand("openocd -f " +  configFile + " -c \"init; reset init; flash write_image erase /Firmware/" + deviceName + "/firmware.bin 0x08000000; verify_image /Firmware/" + deviceName + "/firmware.bin 0x08000000; reset run; shutdown\"")

            // TODO: Check if successful?
            logToConsoles("Flash Operation Complete")

            unlockInstallDevice()
        }
    }
}
