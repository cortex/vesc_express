import QtQuick 2.7
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2
import Vedder.vesc.utility 1.0

import Vedder.vesc.commands 1.0
import Vedder.vesc.utility 1.0

Item {
    id: mainItem
    anchors.fill: parent
    anchors.margins: 5

    property Commands mCommands: VescIf.commands()
    ColumnLayout {
        anchors.fill: parent

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: false
            text: "Pick WiFi Channel Radio Main"
            color: "white"
            wrapMode: Text.WordWrap
        }
        RowLayout{
            Button {
                Layout.fillWidth: true
                text: "Off"

                onClicked: {
                    VescIf.canTmpOverride(true, 21)
                    mCommands.lispSendReplCmd("(def channel -1)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("Disable Wifi", "Done!", true, false)
                }
            }

            Button {
                Layout.fillWidth: true
                text: "1"

                onClicked: {
                    VescIf.canTmpOverride(true, 21)
                    mCommands.lispSendReplCmd("(def channel 1)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("Set Channel", "Done!", true, false)
                }
            }

            Button {
                Layout.fillWidth: true
                text: "6"

                onClicked: {
                    VescIf.canTmpOverride(true, 21)
                    mCommands.lispSendReplCmd("(def channel 6)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("Set Channel", "Done!", true, false)
                }
            }

            Button {
                Layout.fillWidth: true
                text: "13"

                onClicked: {
                    VescIf.canTmpOverride(true, 21)
                    mCommands.lispSendReplCmd("(def channel 13)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("Set Channel", "Done!", true, false)
                }
            }

            Button {
                Layout.fillWidth: true
                text: "14"

                onClicked: {
                    VescIf.canTmpOverride(true, 21)
                    mCommands.lispSendReplCmd("(def channel 14)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("Set Channel", "Done!", true, false)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: false
            text: "Pick WiFi Channel Radio Front"
            color: "white"
            wrapMode: Text.WordWrap
        }
        RowLayout{
            Button {
                Layout.fillWidth: true
                text: "Off"

                onClicked: {
                    VescIf.canTmpOverride(true, 31)
                    mCommands.lispSendReplCmd("(def channel -1)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("Disable Wifi", "Done!", true, false)
                }
            }

            Button {
                Layout.fillWidth: true
                text: "1"

                onClicked: {
                    VescIf.canTmpOverride(true, 31)
                    mCommands.lispSendReplCmd("(def channel 1)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("Set Channel", "Done!", true, false)
                }
            }

            Button {
                Layout.fillWidth: true
                text: "5"

                onClicked: {
                    VescIf.canTmpOverride(true, 31)
                    mCommands.lispSendReplCmd("(def channel 5)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("Set Channel", "Done!", true, false)
                }
            }

            Button {
                Layout.fillWidth: true
                text: "9"

                onClicked: {
                    VescIf.canTmpOverride(true, 31)
                    mCommands.lispSendReplCmd("(def channel 9)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("Set Channel", "Done!", true, false)
                }
            }
        }


        Text {
            Layout.fillWidth: true
            Layout.fillHeight: false
            text: "LTE Modem"
            color: "white"
            wrapMode: Text.WordWrap
        }
        RowLayout{

            Button {
                Layout.fillWidth: true
                text: "OFF"

                onClicked: {
                    VescIf.canTmpOverride(true, 10)
                    mCommands.lispSendReplCmd("(modem-pwr-off)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("Modem switched off", "Done!", true, false)
                }
            }
            Button {
                Layout.fillWidth: true
                text: "ON"

                onClicked: {
                    VescIf.canTmpOverride(true, 10)
                    mCommands.lispSendReplCmd("(modem-pwr-on)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("Modem switched off", "Done!", true, false)
                }
            }
                        Button {
                Layout.fillWidth: true
                text: "GSM"

                onClicked: {
                    VescIf.canTmpOverride(true, 10)
                    mCommands.lispSendReplCmd("(lte-gsm)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("GSM switched ON", "Done!", true, false)
                }
            }
             Button {
                Layout.fillWidth: true
                text: "LTE Cat-1"

                onClicked: {
                    VescIf.canTmpOverride(true, 10)
                    mCommands.lispSendReplCmd("(lte-cat1)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("LTE switched ON", "Done!", true, false)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: false
            text: "NFC"
            color: "white"
            wrapMode: Text.WordWrap
        }
        RowLayout{
            Button {
                Layout.fillWidth: true
                text: "ON"

                onClicked: {
                    VescIf.canTmpOverride(true, 31)
                    mCommands.lispSendReplCmd("(def nfc-enabled 1)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("LTE switched on", "Done!", true, false)
                }
            }
            Button {
                Layout.fillWidth: true
                text: "OFF"

                onClicked: {
                    VescIf.canTmpOverride(true, 31)
                    mCommands.lispSendReplCmd("(def nfc-enabled nil)")
                    VescIf.canTmpOverrideEnd()
                    VescIf.emitMessageDialog("LTE switched ff", "Done!", true, false)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    Component.onCompleted: {

    }

    Component.onDestruction: {

    }
}
