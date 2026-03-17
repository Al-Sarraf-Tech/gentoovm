import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#2D2B55"
            Text {
                anchors.centerIn: parent
                text: "Welcome to GentooVM\n\nA lean, optimized Gentoo desktop\nbuilt for virtual machines."
                color: "white"
                font.pixelSize: 24
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#2D2B55"
            Text {
                anchors.centerIn: parent
                text: "Installing your system...\n\nCinnamon desktop environment\nOptimized for QEMU/KVM\nzram compressed memory"
                color: "white"
                font.pixelSize: 22
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#2D2B55"
            Text {
                anchors.centerIn: parent
                text: "Almost done!\n\nA README will be placed on your Desktop\nwith everything you need to get started."
                color: "white"
                font.pixelSize: 22
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
            }
        }
    }
}
