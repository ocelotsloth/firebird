import QtQuick 2.0
import QtQuick.Layouts 1.0
import QtQuick.Dialogs 1.1
import Firebird.Emu 1.0
import QtQuick.Controls 1.3

Rectangle {
    id: mobileui
    width: 320
    height: 480
    color: "#eee"

    Component.onCompleted: {
        // FIXME: The toast might not yet be registered here

        Emu.useDefaultKit();

        if(Emu.autostart
            && Emu.getFlashPath() !== ""
            && Emu.getSnapshotPath() !== ""
            && Emu.getBoot1Path() !== "")
            Emu.resume();
    }

    Connections {
        target: Qt.application
        onStateChanged: {
            switch (Qt.application.state)
            {
                case Qt.ApplicationSuspended:
                case Qt.ApplicationHidden:
                    Emu.setPaused(true);
                break;
                case Qt.ApplicationActive:
                    Emu.setPaused(false);
                break;
            }
        }
    }

    ColumnLayout {
        id: sidebar
        // In landscape mode fit whole framebuffer on screen
        width: parent.width/350 > parent.height/240 ? parent.width-320*parent.height/240 : parent.width*0.15
        onWidthChanged: update()
        anchors.bottom: controls.top
        anchors.bottomMargin: 0
        anchors.top: parent.top
        anchors.topMargin: 0
        anchors.left: screen.right
        anchors.leftMargin: 0

        SidebarButton {
            id: restartButton

            title: qsTr("Start")
            icon: "qrc:/icons/resources/icons/edit-bomb.png"

            onClicked: {
                Emu.useDefaultKit();
                Emu.restart();
            }
        }

        SidebarButton {
            id: resetButton

            title: qsTr("Reset")
            icon: "qrc:/icons/resources/icons/system-reboot.png"

            onClicked: Emu.reset();
        }

        SidebarButton {
            id: resumeButton

            title: qsTr("Resume")
            icon: "qrc:/icons/resources/icons/system-suspend-hibernate.png"

            onClicked: {
                Emu.useDefaultKit();
                Emu.resume()
            }
        }

        SidebarButton {
            id: saveButton

            title: qsTr("Save")
            icon: "qrc:/icons/resources/icons/media-floppy.png"

            MessageDialog {
                id: saveFailedDialog
                title: qsTr("Error")
                text: qsTr("Failed to save changes!")
                icon: StandardIcon.Warning
            }

            MessageDialog {
                id: snapWarnDialog
                title: qsTr("Warning")
                text: qsTr("Flash saved, but no snapshot location configured.\nYou won't be able to resume.")
                icon: StandardIcon.Warning
            }

            onClicked: {
                var flash_path = Emu.getFlashPath();
                var snap_path = Emu.getSnapshotPath();

                if(flash_path === "" || !Emu.saveFlash())
                    saveFailedDialog.visible = true;
                else
                {
                    if(snap_path)
                        Emu.suspend();
                    else
                        snapWarnDialog.visible = true;
                }
            }
        }

    }

    EmuScreen {
        id: screen
        focus: true
        y: 0
        width: parent.width - sidebar.width
        height: width/320*240
        anchors.left: parent.left
        anchors.leftMargin: 0

        Timer {
            interval: 20
            running: true; repeat: true
            onTriggered: screen.update()
        }
    }

    /* This implements multiple pages next to each other, which can be switched
      by swiping left or right. */

    Item {
        id: controls
        anchors {
            top: screen.bottom
            bottom: parent.bottom
            right: parent.right
            left: parent.left
        }
        clip: true

        // Index of the page in front
        property int currentIndex: 0
        // X offset
        property int currentSwipeOffset: 0
        // Y offset
        property int currentScrollOffset: 0
        // Maximum value of currentIndex
        property int maxIndex: 1

        MouseArea {
            anchors.fill: parent
            property var origin
            property int moveThreshold: parent.height * 0.2

            onPressed: origin = Qt.point(mouse.x, mouse.y)

            onPositionChanged: {
                var newSwipeOffset = origin.x - mouse.x;
                if(parent.currentIndex == 0 && newSwipeOffset < 0)
                    newSwipeOffset = 0;
                else if(parent.currentIndex == parent.maxIndex && newSwipeOffset > 0)
                    newSwipeOffset = 0;

                parent.currentSwipeOffset = newSwipeOffset;

                if(Math.abs(parent.currentSwipeOffset) > moveThreshold)
                {
                    var newCurrentIndex = parent.currentIndex + (parent.currentSwipeOffset < 0 ? -1 : 1);

                    origin.x = mouse.x;
                    parent.currentSwipeOffset = 0;
                    if(newCurrentIndex >= 0 && newCurrentIndex <= parent.maxIndex)
                        parent.currentIndex = newCurrentIndex;
                }

                var maxScrollOffset = mobilecontrol1.height - parent.height;
                var newScrollOffset = parent.currentScrollOffset + origin.y - mouse.y;
                parent.currentScrollOffset = Math.max(0, Math.min(newScrollOffset, maxScrollOffset));
                origin.y = mouse.y;
            }

            onReleased: parent.currentSwipeOffset = 0;
        }

        Row {
            id: controlsRow
            x: parent.currentIndex * -width - parent.currentSwipeOffset
            y: -parent.currentScrollOffset
            Behavior on x { NumberAnimation { duration: 200 } }
            width: parent.width
            height: parent.height

            Item {
                id: mobilecontrol1
                height: keypad.height*controls.width/keypad.width + iosmargin.height
                width: controls.width

                Keypad {
                    id: keypad
                    transform: Scale { origin.x: 0; origin.y: 0; xScale: controls.width/keypad.width; yScale: controls.width/keypad.width }
                }

                Item {
                    id: iosmargin
                    // This is needed to avoid opening the control center
                    height: Qt.platform.os === "ios" ? 20 : 0
                }
            }

            MobileControl2 {
                id: control2
                height: mobilecontrol1.height
                width: controls.width
            }
        }
    }

    Rectangle {
        id: toast
        x: 60
        z: 1
        implicitWidth: message.width+2*5
        implicitHeight: message.height+2*5

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 61
        anchors.horizontalCenter: parent.horizontalCenter

        radius: 5
        color: "#d3c7c7"
        border.color: "#e66e6e6e"
        border.width: 3

        opacity: 0
        visible: opacity > 0

        Component.onCompleted: Emu.registerToast(this)

        Behavior on opacity { NumberAnimation { duration: 200 } }

        function showMessage(str) {
            message.text = str;
            opacity = 1;
            timer.restart();
        }

        Text {
            id: message
            text: "Text"
            anchors.centerIn: parent
            font.pointSize: 12

            Timer {
                id: timer
                interval: 2000
                onTriggered: parent.parent.opacity = 0;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                timer.stop();
                parent.opacity = 0;
            }
        }
    }
}

