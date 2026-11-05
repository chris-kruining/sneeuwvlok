import QtQuick
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami
// for the fader's shader
import org.kde.breeze.components

// What the login screen leaves behind once the password field fades out: the wallpaper of the day, blurred and toned
// like breeze's WallpaperFader does it when the ui is up. Up at once, no intro, so the session starting looks like the
// login screen staying put
Rectangle {
    id: root
    color: "black"

    property int stage

    Image {
        id: wallpaper
        anchors.fill: parent
        source: "@wallpaper@" ? "file://@wallpaper@" : ""
        fillMode: Image.PreserveAspectCrop
        cache: false
        visible: false
    }

    FastBlur {
        id: wallpaperBlur
        anchors.fill: parent
        source: wallpaper
        radius: 50
    }

    // the fader's colour matrix at its "on" end
    ShaderEffect {
        anchors.fill: parent
        visible: wallpaper.status === Image.Ready
        supportsAtlasTextures: true
        property var source: ShaderEffectSource {
            sourceItem: wallpaperBlur
            live: true
            hideSource: true
            textureMirroring: ShaderEffectSource.NoMirroring
        }

        readonly property bool lightColorScheme: Math.max(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b) > 0.5
        readonly property real contrast: 0.8
        readonly property real saturation: 1.5
        readonly property real intensity: lightColorScheme ? 1.6 : 0.7

        readonly property real transl: (1.0 - contrast) / 2.0
        readonly property real rval: (1.0 - saturation) * 0.2126
        readonly property real gval: (1.0 - saturation) * 0.7152
        readonly property real bval: (1.0 - saturation) * 0.0722

        property var colorMatrix: Qt.matrix4x4(
            contrast, 0,        0,        0.0,
            0,        contrast, 0,        0.0,
            0,        0,        contrast, 0.0,
            transl,   transl,   transl,   1.0).times(Qt.matrix4x4(
                rval + saturation, rval,     rval,     0.0,
                gval,     gval + saturation, gval,     0.0,
                bval,     bval,     bval + saturation, 0.0,
                0,        0,        0,        1.0)).times(Qt.matrix4x4(
                    intensity, 0,         0,         0,
                    0,         intensity, 0,         0,
                    0,         0,         intensity, 0,
                    0,         0,         0,         1
                ))

        fragmentShader: "qrc:/qt/qml/org/kde/breeze/components/shaders/WallpaperFader.frag.qsb"
    }
}
