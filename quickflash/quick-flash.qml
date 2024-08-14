
import QtQuick 2.7
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import Vedder.vesc.vescinterface 1.0
import Vedder.vesc.esp32flash 1.0
import Vedder.vesc.utility 1.0
import Vedder.vesc.codeloader 1.0

Item {
    id: mainItem
    anchors.fill: parent

    // TODO: Provide path to your LIND/Firmware/build directory
    property string filesLocation: "/home/renee/LIND/Firmware/build/"

    CodeLoader {
        id: mLoader
        Component.onCompleted: {
            mLoader.setVesc(VescIf)
        }
    }

    Connections {
        target: VescIf

        function onFwUploadStatus(status, progress, isOngoing) {
            if (isOngoing) {
                uploadText.text = status + " (" + parseFloat(progress * 100.0).toFixed(2) + " %)"
            } else {
                uploadText.text = status
            }

            progressBarValue = progress
        }
    }

    property double progressBarValue: 0

    Component.onCompleted: {

    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 10

        Button { text: "Erase Lisp on all devices"; Layout.fillWidth: true; onClicked: eraseAllLBM() }
        Button { text: "Update VESC on all devices"; Layout.fillWidth: true; onClicked: flashAllVESC() }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignBottom
            color: Utility.getAppHexColor("lightText")
            id: uploadText
            text: qsTr("Not Uploading")
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

    }

    function eraseAllLBM() {
        console.log("Erasing LBM Scripts")
        var canIds = VescIf.scanCan()
        console.log(canIds)
        mLoader.lispErase(10240)
        console.log("LBM erased locally")
        for (var i = 0; i < canIds.length; i++) {
            VescIf.canTmpOverride(true, canIds[i])
            var eraseSize = 512 * 1024 // ESP32 has 512KB, STM32 has 128KB
            switch (canIds[i]) {
                case 10: //bat-esc-stm
                case 20: //bat-bms-stm
                case 30: //bat-ant-stm
                    eraseSize = 128 * 1024
                    break;
            }
            mLoader.lispErase(eraseSize)
            VescIf.canTmpOverrideEnd()
            console.log("LBM erased on CAN ID " + canIds[i])
        }
        console.log("Done")
    }

    function flashFw(canId, filePath) {
        var success = false
        do {
            success = VescIf.fwUpdate(Utility.readAllFromFile(filePath))
            if (!success) console.log("Retrying CAN ID " + canId)
        } while (!success)
    }

    function flashAllVESC() {
        console.log("Scanning CAN")
        var canIds = VescIf.scanCan()
        console.log(canIds)

        console.log("Installing VESC FW")
        for (var i = 0; i < canIds.length; i++) {
            VescIf.canTmpOverride(true, canIds[i])
            switch (canIds[i]) {
                case 10:
                    flashFw(canIds[i], filesLocation + "bat-esc-stm/firmware.bin")
                    break;
                case 20:
                    flashFw(canIds[i], filesLocation + "bat-bms-stm/firmware.bin")
                    break;
                case 21:
                    flashFw(canIds[i], filesLocation + "bat-bms-esp/firmware.bin")
                    break;
                case 30:
                    flashFw(canIds[i], filesLocation + "bat-ant-stm/firmware.bin")
                    break;
                case 31:
                    flashFw(canIds[i], filesLocation + "bat-ant-esp/firmware.bin")
                    break;
                case 40:
                    flashFw(canIds[i], filesLocation + "jet-if-esp/firmware.bin")
                    break;
                default:
                    console.log("Unknown CAN ID " + canIds[i])
            }
            VescIf.canTmpOverrideEnd()
            console.log("FW installed on CAN ID " + canIds[i])
        }

        console.log("Done")
    }
}
