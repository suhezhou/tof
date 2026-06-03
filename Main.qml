import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: window

    width: 1320
    height: 820
    minimumWidth: 1180
    minimumHeight: 720
    visible: true
    title: "超声测距上位机"
    color: "#eef1f6"

    property bool portOpened: false
    property bool displayRunning: false
    property bool saveDataEnabled: false
    property bool showTimestampEnabled: true
    property real currentDistance: 0
    property string receiveText: ""
    property int maxSamples: 40
    property color panelColor: "#ffffff"
    property color sectionColor: "#f8fafc"
    property color borderColor: "#d9e1ea"
    property color accentColor: "#2f6fed"
    property color accentSoft: "#e8f0ff"
    property color textStrong: "#1f2937"
    property color textMuted: "#64748b"

    component AppPanel: Rectangle {
        radius: 18
        color: window.panelColor
        border.color: window.borderColor
        border.width: 1
    }

    component AppSection: Rectangle {
        radius: 14
        color: window.sectionColor
        border.color: window.borderColor
        border.width: 1
    }

    component AppButton: Button {
        id: control
        implicitHeight: 40
        font.pixelSize: 15

        background: Rectangle {
            radius: 12
            color: control.highlighted
                   ? (control.down ? "#245ed2" : window.accentColor)
                   : (control.down ? "#dde7f5" : "#f7f9fc")
            border.color: control.highlighted ? window.accentColor : window.borderColor
        }

        contentItem: Text {
            text: control.text
            font: control.font
            color: control.highlighted ? "#ffffff" : window.textStrong
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    component AppField: TextField {
        implicitHeight: 42
        font.pixelSize: 15
        selectByMouse: true

        background: Rectangle {
            radius: 12
            color: "#ffffff"
            border.color: window.borderColor
            border.width: 1
        }
    }

    component AppCombo: ComboBox {
        implicitHeight: 30

        background: Rectangle {
            radius: 12
            color: "#ffffff"
            border.color: window.borderColor
            border.width: 1
        }
    }

    function nowText() {
        return Qt.formatDateTime(new Date(), "hh:mm:ss");
    }

    function formatDistance(value) {
        return Number(value).toFixed(1);
    }

    function appendReceiveLine(prefix, payload) {
        let line = prefix + " " + payload;

        if (showTimestampEnabled)
            line = "[" + nowText() + "] " + line;

        receiveText = line + "\n" + receiveText;
    }

    function clearReceive() {
        receiveText = "";
    }

    function clearSamples() {
        sampleModel.clear();
        currentDistance = 0;
        chartCanvas.requestPaint();
    }

    function initializeAll() {
        displayRunning = false;
        clearSamples();
        clearReceive();
        manualInput.text = "";
        appendReceiveLine("SYS", "系统已初始化");
    }

    function appendSample(value) {
        currentDistance = value;

        sampleModel.append({
            "x": sampleModel.count + 1,
            "y": value
        });

        while (sampleModel.count > maxSamples) {
            for (let i = 0; i < sampleModel.count - 1; ++i) {
                sampleModel.setProperty(i, "x", i + 1);
                sampleModel.setProperty(i, "y", sampleModel.get(i + 1).y);
            }
            sampleModel.remove(sampleModel.count - 1);
        }

        chartCanvas.requestPaint();

        if (saveDataEnabled)
            appendReceiveLine("SYS", "数据已缓存: " + formatDistance(value) + " cm");
    }

    function generateMockDistance() {
        const base = 55 + Math.sin(Date.now() / 900) * 16;
        const noise = (Math.random() - 0.5) * 4.5;
        return Math.max(5, base + noise);
    }

    function performMeasurement(triggerText) {
        if (!portOpened) {
            appendReceiveLine("SYS", "请先打开串口");
            return;
        }

        const value = generateMockDistance();

        if (triggerText)
            appendReceiveLine("TX", triggerText);

        appendReceiveLine("RX", "DIST," + formatDistance(value) + ",cm");
        appendSample(value);
    }

    function sendManualCommand() {
        const command = manualInput.text.trim();

        if (command.length === 0) {
            appendReceiveLine("SYS", "发送区不能为空");
            return;
        }

        if (!portOpened) {
            appendReceiveLine("SYS", "串口未打开，无法发送");
            return;
        }

        appendReceiveLine("TX", command);

        if (command === "MEASURE?" || command === "START_STREAM") {
            const value = generateMockDistance();
            appendReceiveLine("RX", "DIST," + formatDistance(value) + ",cm");
            appendSample(value);
        } else if (command === "STOP_STREAM") {
            displayRunning = false;
            appendReceiveLine("SYS", "已停止连续显示");
        } else {
            appendReceiveLine("RX", "ACK," + command);
        }
    }

    Timer {
        id: mockTimer
        interval: 700
        repeat: true
        running: displayRunning && portOpened

        onTriggered: performMeasurement("")
    }

    ListModel {
        id: sampleModel
    }

    Rectangle {
        anchors.fill: parent
        color: "#eef1f6"
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 16

        AppPanel {
            Layout.preferredWidth: 292
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                Label {
                    text: "串口参数设置"
                    font.pixelSize: 21
                    font.bold: true
                    color: textStrong
                }

                AppSection {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 235

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Label {
                            text: "基础参数"
                            font.pixelSize: 16
                            font.bold: true
                            color: textStrong
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 5

                            Label {
                                text: "串口"
                                font.pixelSize: 16
                                color: textStrong
                            }

                            AppCombo {
                                id: portBox
                                Layout.fillWidth: true
                                model: ["COM1", "COM2", "COM3", "COM4", "COM5"]
                                currentIndex: 2
                            }

                            Label {
                                text: "波特率"
                                font.pixelSize: 16
                                color: textStrong
                            }

                            AppCombo {
                                id: baudBox
                                Layout.fillWidth: true
                                model: ["9600", "19200", "38400", "57600", "115200"]
                                currentIndex: 4
                            }

                            Label {
                                text: "数据位"
                                font.pixelSize: 16
                                color: textStrong
                            }

                            AppCombo {
                                id: dataBitsBox
                                Layout.fillWidth: true
                                model: ["5", "6", "7", "8"]
                                currentIndex: 3
                            }

                            Label {
                                text: "校验位"
                                font.pixelSize: 16
                                color: textStrong
                            }

                            AppCombo {
                                id: parityBox
                                Layout.fillWidth: true
                                model: ["无", "奇校验", "偶校验"]
                                currentIndex: 0
                            }

                            Label {
                                text: "停止位"
                                font.pixelSize: 16
                                color: textStrong
                            }

                            AppCombo {
                                id: stopBitsBox
                                Layout.fillWidth: true
                                model: ["1", "1.5", "2"]
                                currentIndex: 0
                            }
                        }
                    }
                }

                // AppSection {
                //     Layout.fillWidth: true
                //     Layout.preferredHeight: 50

                //     ColumnLayout {
                //         anchors.fill: parent
                //         anchors.margins: 12
                //         spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            AppButton {
                                Layout.fillWidth: true
                                text: portOpened ? "关闭串口" : "打开串口"
                                highlighted: true

                                onClicked: {
                                    if (!portOpened) {
                                        portOpened = true;
                                        appendReceiveLine("SYS",
                                                          "串口已打开: "
                                                          + portBox.currentText
                                                          + " / "
                                                          + baudBox.currentText
                                                          + " / 数据位 "
                                                          + dataBitsBox.currentText
                                                          + " / "
                                                          + parityBox.currentText
                                                          + " / 停止位 "
                                                          + stopBitsBox.currentText);
                                    } else {
                                        displayRunning = false;
                                        portOpened = false;
                                        appendReceiveLine("SYS", "串口已关闭");
                                    }
                                }
                            }

                            AppButton {
                                Layout.fillWidth: true
                                text: "清空接收"

                                onClicked: clearReceive()
                            }
                        }
                //     }
                // }

                AppSection {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 324

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Label {
                            text: "发送数据"
                            font.pixelSize: 17
                            font.bold: true
                            color: textStrong
                        }

                        Label {
                            text: "输入指令后发送，支持例如 MEASURE? / START_STREAM"
                            font.pixelSize: 13
                            color: textMuted
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        AppField {
                            id: manualInput
                            Layout.fillWidth: true
                            placeholderText: "输入发送内容，例如 MEASURE?"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            CheckBox {
                                id: hexCheckBox
                                text: "接收数据"
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            AppButton {
                                text: "Send"
                                implicitWidth: 88
                                highlighted: true

                                onClicked: sendManualCommand()
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            AppButton {
                                Layout.fillWidth: true
                                text: "测量"
                                enabled: portOpened

                                onClicked: performMeasurement("MEASURE?")
                            }

                            AppButton {
                                Layout.fillWidth: true
                                text: "初始化"

                                onClicked: initializeAll()
                            }
                        }
                        CheckBox {
                            text: "保存数据"
                            checked: saveDataEnabled

                            onToggled: saveDataEnabled = checked
                        }

                        CheckBox {
                            text: "显示接收数据时间"
                            checked: showTimestampEnabled

                            onToggled: showTimestampEnabled = checked
                        }
                    }
                }

                // AppSection {
                //     Layout.fillWidth: true
                //     Layout.preferredHeight: 92

                //     ColumnLayout {
                //         anchors.fill: parent
                //         anchors.margins: 12
                //         spacing: 8


                //     }
                // }

                // Item {
                //     Layout.fillHeight: true
                // }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: 14
                    color: portOpened ? "#dcfce7" : "#fee2e2"
                    border.color: portOpened ? "#86efac" : "#fca5a5"

                    Label {
                        anchors.centerIn: parent
                        text: portOpened ? "串口状态：已连接" : "串口状态：未连接"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#1f2937"
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            AppPanel {
                Layout.fillWidth: true
                Layout.preferredHeight: 300

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Label {
                        text: "接收数据显示区"
                        font.pixelSize: 19
                        font.bold: true
                        color: textStrong
                    }

                    AppSection {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TextArea {
                            id: receiveArea
                            anchors.fill: parent
                            anchors.margins: 10
                            readOnly: true
                            text: receiveText
                            wrapMode: TextEdit.WrapAnywhere
                            font.family: "Consolas"
                            font.pixelSize: 14
                            selectByMouse: true

                            background: null
                        }
                    }
                }
            }

            AppPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true

                        Label {
                            text: "实时曲线显示区"
                            font.pixelSize: 19
                            font.bold: true
                            color: textStrong
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Label {
                            text: sampleModel.count > 0
                                  ? "当前距离: " + formatDistance(currentDistance) + " cm"
                                  : "当前距离: --.- cm"
                            font.pixelSize: 16
                            color: textMuted
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        AppButton {
                            text: "开始显示"
                            enabled: portOpened && !displayRunning
                            highlighted: true

                            onClicked: {
                                displayRunning = true;
                                appendReceiveLine("SYS", "开始连续显示");
                            }
                        }

                        AppButton {
                            text: "停止显示"
                            enabled: displayRunning

                            onClicked: {
                                displayRunning = false;
                                appendReceiveLine("SYS", "停止连续显示");
                            }
                        }

                        AppButton {
                            text: "初始化"

                            onClicked: initializeAll()
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    AppSection {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Canvas {
                            id: chartCanvas
                            anchors.fill: parent
                            anchors.margins: 10

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();

                                const left = 56;
                                const top = 18;
                                const right = width - 18;
                                const bottom = height - 38;
                                const plotWidth = right - left;
                                const plotHeight = bottom - top;
                                const yMin = 0;
                                const yMax = 100;
                                const xCount = Math.max(sampleModel.count, 8);

                                ctx.fillStyle = "#ffffff";
                                ctx.fillRect(0, 0, width, height);

                                ctx.strokeStyle = "#222222";
                                ctx.lineWidth = 1;
                                ctx.strokeRect(left, top, plotWidth, plotHeight);

                                ctx.strokeStyle = "#cbd5e1";
                                ctx.fillStyle = "#334155";
                                ctx.font = "12px sans-serif";

                                for (let i = 0; i <= 5; ++i) {
                                    const y = top + (plotHeight / 5) * i;
                                    const value = yMax - ((yMax - yMin) / 5) * i;

                                    ctx.beginPath();
                                    ctx.moveTo(left, y);
                                    ctx.lineTo(right, y);
                                    ctx.stroke();

                                    ctx.fillText(String(Math.round(value)), 18, y + 4);
                                }

                                for (let i = 0; i < 8; ++i) {
                                    const x = left + (plotWidth / 7) * i;

                                    ctx.beginPath();
                                    ctx.moveTo(x, top);
                                    ctx.lineTo(x, bottom);
                                    ctx.stroke();

                                    ctx.fillText(String(i + 1), x - 4, bottom + 20);
                                }

                                if (sampleModel.count === 0)
                                    return;

                                ctx.strokeStyle = "#60a5fa";
                                ctx.lineWidth = 2;
                                ctx.beginPath();

                                for (let i = 0; i < sampleModel.count; ++i) {
                                    const point = sampleModel.get(i);
                                    const x = left + (plotWidth / Math.max(xCount - 1, 1)) * i;
                                    const y = bottom - ((point.y - yMin) / (yMax - yMin)) * plotHeight;

                                    if (i === 0)
                                        ctx.moveTo(x, y);
                                    else
                                        ctx.lineTo(x, y);
                                }

                                ctx.stroke();

                                ctx.fillStyle = "#2563eb";
                                for (let i = 0; i < sampleModel.count; ++i) {
                                    const point = sampleModel.get(i);
                                    const x = left + (plotWidth / Math.max(xCount - 1, 1)) * i;
                                    const y = bottom - ((point.y - yMin) / (yMax - yMin)) * plotHeight;
                                    ctx.beginPath();
                                    ctx.arc(x, y, 3, 0, Math.PI * 2);
                                    ctx.fill();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        appendReceiveLine("SYS", "原型界面已启动");
        appendReceiveLine("SYS", "当前为模拟串口模式，可先验证界面与流程");
    }
}
