import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import Vedder.vesc.utility 1.0
import Vedder.vesc.commands 1.0
import Vedder.vesc.configparams 1.0
import Vedder.vesc.tcphub 1.0

Item {
    id: mainItem
    anchors.fill: parent
    anchors.margins: 5

    property Commands mCommands: VescIf.commands()
    property ConfigParams mMcConf: VescIf.mcConfig()
    property var progress: 0.3
    property var throttle: 0
    property var testMaxTime: 600

    Component.onCompleted: {
        console.log("started")
    }

    ColumnLayout{
        anchors.fill: parent

        ProgressBar{
            Layout.fillWidth: true
            value: throttle

        }
        ProgressBar{
            Layout.fillWidth: true
            value: progress
            to: testMaxTime
        }
        RowLayout{
            Layout.fillWidth: true
            Button{
                text: "Start test"
                id: startButton
                enabled: false
                Layout.fillWidth: true
                Layout.preferredWidth: 10000

                onClicked: {
                    testTimer.running = true
                    progress = 0
                }
            }
            Button{
                text: "Stop test"
                Layout.fillWidth: true
                Layout.preferredWidth: 10000

                onClicked: {
                    testTimer.running = false
                    progress = 0
                }
            }
        }

        Timer{
            id: testTimer
            running: false
            repeat: true
            interval: 100

            onTriggered:{

                progress += 0.1
                var steps = 4
                var cycleLength = 2; // length of cycle in seconds
                var minThrottle = 0.2
                var maxThrottle = 0.8
                throttle = minThrottle + (Math.round(steps * (progress % cycleLength) / cycleLength) / steps) * (maxThrottle - minThrottle)
                console.log(throttle)
                mCommands.lispSendReplCmd("(thr-rx " + throttle + ")")
                if (progress >= testMaxTime){
                    stop()
                }
            }
        }

        Item{
            Layout.fillHeight: true
        }
        Button{
            text: "ARM"
            Layout.fillWidth: true
            Layout.preferredWidth: 10000

            onClicked: {
                startButton.enabled = true
                disableStart.t = 0
                disableStart.start()
            }
        }

        ProgressBar{
        id: countdown
            background: Rectangle {
                implicitWidth: 200
                implicitHeight: 6
                color: "grey"
                radius: 3
            }

            contentItem: Item {
                implicitWidth: 200
                implicitHeight: 4

                Rectangle {
                    width: countdown.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: "red"
                }
            }
            from: 0
            to: 10
            value: 10 - disableStart.t


            Layout.fillWidth: true
        }

        Timer {
            id: disableStart
            repeat: true
            running: false
            interval: 100
            property var t: 0
            onTriggered: {
                t += 0.1
                if (t > 10){
                    startButton.enabled = false
                    stop()
                }
            }
        }
    }

}
