import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasma5support as P5Support

ColumnLayout {
    id: clock

    property Item shadow: null
    readonly property date now: timeSource.data["Local"]["DateTime"]

    spacing: 0

    FontLoader { id: display; source: "file://@anurati@" }
    FontLoader { id: body; source: "file://@poppins@" }

    P5Support.DataSource {
        id: timeSource
        engine: "time"
        connectedSources: ["Local"]
        interval: 1000
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: Qt.formatDate(clock.now, "dddd").toUpperCase()
        color: "white"
        font.family: display.font.family
        font.pixelSize: 110
        font.letterSpacing: 26
        leftPadding: 26
        renderType: Text.CurveRendering
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 8
        text: Qt.formatDate(clock.now, "dd MMM yyyy").toUpperCase()
        color: "white"
        font.family: body.font.family
        font.pixelSize: 26
        font.letterSpacing: 4
        leftPadding: 4
        renderType: Text.CurveRendering
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 2
        text: "- " + Qt.formatTime(clock.now, "HH:mm") + " -"
        color: "white"
        font.family: body.font.family
        font.pixelSize: 26
        font.letterSpacing: 4
        leftPadding: 4
        renderType: Text.CurveRendering
    }
}
