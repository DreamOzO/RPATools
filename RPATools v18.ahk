#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")
try DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
SendMode("Input")   ; 全局切换到 SendInput，避免 Ctrl+A 修饰键丢失导致的 a 泄漏

; ============ 全局变量 ============
global TaskArr := [] 
global IsPaused := false 
global IsStopped := false 
global OCR_X := 0, OCR_Y := 0, OCR_W := 100, OCR_H := 30 
global EditingIndex := 0
global DebugStartIP := 1
global OCR_Result := "" 
global OCR_Keyword := "" 
global VarPool := Map("LoopCount_OCR", 0)
global g_RetryCounter := Map()
global FailPolicy := "stop"
global LogEnabled := false
global LogPath := A_ScriptDir "\run.log"
global SilentMode := false

; 【优化】CSV缓存Map
global CSVCache := Map("KeyValues", Map(), "Coords", Map(), "Range", Map(), "MultiMap", Map())

global TypeList := [
    "🚀 启动应用/快捷方式",
	"激活窗口",
    "📝 设置变量",
    "点击坐标",
    "发送按键",
    "延时等待",
    "截图找图",
    "识别并填写",
	"🔍 OCR识别保存文本",
    "🎯 匹配文本并点击",
    "🎲 范围随机填写",
    "📊 坐标查表填写",
    "🕹️ 条件跳过",
    "🔁 局部循环开始",
    "🔚 局部循环结束",
    "🔀 条件分支开始 (If)",
    "🔀 否则 (Else)",
    "🔀 分支结束 (EndIf)",
    "📦 调用子脚本",
]

; ================= UI =================
MyGui := Gui("+Resize", "自动化任务管理器 (终极整合版 v18)")
MyGui.SetFont("s10", "Microsoft YaHei")
MyGui.Opt("+MinSize720x960")

MyGui.Add("GroupBox", "xm ym w700 h440", "添加任务")
MyGui.Add("Text", "x15 y25 w70", "任务类型：")
TypeDDL := MyGui.Add("DropDownList", "x90 y23 w220", TypeList)
TypeDDL.Value := 1
TypeDDL.OnEvent("Change", ChangeType)

; ============ 激活窗口 ============
ParamWinTitle := MyGui.Add("Text", "x15 y60 hidden", "窗口标题：")
InputWinTitle := MyGui.Add("Edit", "x90 y58 w250 hidden", "ahk_exe chrome.exe")
BtnGetWin := MyGui.Add("Button", "x350 y57 w100 hidden", "捕获当前窗口")
BtnGetWin.OnEvent("Click", GetWinInfo)
ParamWinWait := MyGui.Add("Text", "x15 y90 hidden", "最长等待(秒)：")
InputWinWait := MyGui.Add("Edit", "x120 y88 w60 hidden", "0")
ParamWinWaitHint := MyGui.Add("Text", "x190 y90 w300 hidden", "(0=立即激活一次；>0=循环等到窗口出现)")

; ============ 启动应用 ============
ParamAppPath := MyGui.Add("Text", "x15 y60 hidden", "应用/快捷方式：")
InputAppPath := MyGui.Add("Edit", "x110 y58 w290 hidden", "")
BtnSelApp   := MyGui.Add("Button", "x405 y57 w110 hidden", "📂 浏览选择")
BtnSelApp.OnEvent("Click", SelectApp)
ParamAppArgs := MyGui.Add("Text", "x15 y90 hidden", "启动参数：")
InputAppArgs := MyGui.Add("Edit", "x90 y88 w300 hidden", "")
ParamAppWait := MyGui.Add("Text", "x15 y120 hidden", "启动后等待(ms)：")
InputAppWait := MyGui.Add("Edit", "x130 y118 w60 hidden", "1500")
ParamAppWin  := MyGui.Add("Text", "x210 y120 hidden", "激活窗口：")
InputAppWin  := MyGui.Add("Edit", "x300 y118 w180 hidden", "")
BtnAppGetWin := MyGui.Add("Button", "x485 y117 w100 hidden", "捕获当前窗口")
BtnAppGetWin.OnEvent("Click", (*) => CaptureWindowTitle(InputAppWin))

; ============ 点击坐标（支持自定义次数） ============
ParamX := MyGui.Add("Text", "x15 y60 hidden", "X坐标：")
InputX := MyGui.Add("Edit", "x70 y58 w50 hidden")
ParamY := MyGui.Add("Text", "x130 y60 hidden", "Y坐标：")
InputY := MyGui.Add("Edit", "x180 y58 w50 hidden")
ParamOffsetX := MyGui.Add("Text", "x240 y60 hidden", "X偏移：")
InputOffsetX := MyGui.Add("Edit", "x290 y58 w40 hidden", "0")
ParamOffsetY := MyGui.Add("Text", "x340 y60 hidden", "Y偏移：")
InputOffsetY := MyGui.Add("Edit", "x390 y58 w40 hidden", "0")
BtnGetPos := MyGui.Add("Button", "x450 y57 w90 hidden", "获取鼠标坐标")
BtnGetPos.OnEvent("Click", GetMousePos)

ParamClickCount := MyGui.Add("Text", "x15 y90 hidden", "点击次数：")
ClickCountDDL := MyGui.Add("ComboBox", "x90 y88 w80 hidden", ["1", "2", "3", "5", "10"])
ClickCountDDL.Text := "1"
ParamText := MyGui.Add("Text", "x185 y90 hidden", "点击后输入：")
InputText := MyGui.Add("Edit", "x265 y88 w180 hidden")
ChkPasteClip := MyGui.Add("CheckBox", "x455 y90 w90 hidden", "粘贴剪贴板")
ChkReplace := MyGui.Add("CheckBox", "x555 y90 w130 hidden Checked", "覆盖原内容(Ctrl+A)")

; ============ 发送按键 ============
ParamKey := MyGui.Add("Text", "x15 y60 hidden", "输入按键：")
InputKey := MyGui.Add("Edit", "x90 y58 w120 hidden", "{Tab}")
BtnKeyTab := MyGui.Add("Button", "x220 y57 w50 hidden", "Tab键")
BtnKeyTab.OnEvent("Click", (*) => InputKey.Value := "{Tab}")
BtnKeyEnter := MyGui.Add("Button", "x275 y57 w50 hidden", "回车")
BtnKeyEnter.OnEvent("Click", (*) => InputKey.Value := "{Enter}")
BtnKeyEsc := MyGui.Add("Button", "x330 y57 w50 hidden", "Esc")
BtnKeyEsc.OnEvent("Click", (*) => InputKey.Value := "{Esc}")

; ============ 延时等待 ============
ParamMs := MyGui.Add("Text", "x15 y60 hidden", "等待时间：")
InputMs := MyGui.Add("Edit", "x100 y58 w100 hidden", "500")

; ============ 截图找图 ============
ParamImg := MyGui.Add("Text", "x15 y60 hidden", "图片路径：")
InputImg := MyGui.Add("Edit", "x90 y58 w250 hidden")
BtnSelectImg := MyGui.Add("Button", "x350 y57 w80 hidden", "浏览选择")
BtnSelectImg.OnEvent("Click", SelectImage)
BtnCapture := MyGui.Add("Button", "x440 y57 w80 hidden", "✂ 截取屏幕")
BtnCapture.OnEvent("Click", StartCapture)
ParamImgAction := MyGui.Add("Text", "x15 y90 hidden", "找到后动作：")
ImgActionDDL := MyGui.Add("DropDownList", "x105 y88 w150 hidden", ["点击图片中心", "点击图片左上角", "仅移动不点击"])
ImgActionDDL.Value := 1
ParamImgOffX := MyGui.Add("Text", "x270 y90 hidden", "X偏移：")
InputImgOffX := MyGui.Add("Edit", "x325 y88 w45 hidden", "0")
ParamImgOffY := MyGui.Add("Text", "x380 y90 hidden", "Y偏移：")
InputImgOffY := MyGui.Add("Edit", "x430 y88 w45 hidden", "0")
ParamImgSim := MyGui.Add("Text", "x490 y90 hidden", "相似度：")
InputImgSim := MyGui.Add("Edit", "x555 y88 w45 hidden", "70")
ParamImgWait := MyGui.Add("Text", "x15 y120 hidden", "最长等待(秒)：")
InputImgWait := MyGui.Add("Edit", "x120 y118 w60 hidden", "0")
ParamImgWaitHint := MyGui.Add("Text", "x190 y120 w400 hidden", "(0=只搜一次；>0=循环搜直到超时，超时算失败)")

; ============ 识别并填写 ============
ParamOcrArea := MyGui.Add("Text", "x15 y60 hidden", "识别区域：")
InputOcrArea := MyGui.Add("Edit", "x90 y58 w200 hidden ReadOnly", "未选择区域")
BtnSelectArea := MyGui.Add("Button", "x300 y57 w80 hidden", "框选区域")
BtnSelectArea.OnEvent("Click", SelectOcrArea)

ChkExtractNum := MyGui.Add("CheckBox", "x15 y90 w110 hidden Checked", "仅提取数字")
ChkExtractNum.OnEvent("Click", UpdateExtractNumUI)
ChkKeepDot := MyGui.Add("CheckBox", "x130 y90 w90 hidden Checked", "保留小数点")
ChkRound1 := MyGui.Add("CheckBox", "x225 y90 w160 hidden", "保留1位小数(四舍五入)")
ChkOnlyClip := MyGui.Add("CheckBox", "x390 y90 w140 hidden", "仅识别存入剪贴板")

ParamMath := MyGui.Add("Text", "x15 y120 hidden", "数学运算：")
InputMath := MyGui.Add("Edit", "x90 y118 w80 hidden", "")
ParamMathHint := MyGui.Add("Text", "x175 y120 hidden", "(如 +5, *1.2；仅对数字生效)")
ChkUseDB := MyGui.Add("CheckBox", "x370 y118 w110 hidden", "查表替换(CSV)")
InputDBPath := MyGui.Add("Edit", "x370 y148 w170 hidden ReadOnly", "DataMap.csv")
BtnDBPath := MyGui.Add("Button", "x570 y147 w60 hidden", "选表...")
BtnDBPath.OnEvent("Click", SelectDB)
BtnGenDB := MyGui.Add("Button", "x640 y147 w60 hidden", "模板")
BtnGenDB.OnEvent("Click", GenerateDBTemplate)

ChkSendText := MyGui.Add("CheckBox", "x15 y178 w200 hidden Checked", "用 SendText 填（纯ASCII）")
ChkSaveToVar := MyGui.Add("CheckBox", "x230 y178 w150 hidden", "存入变量（不填表）")
ChkSaveToVar.OnEvent("Click", UpdateSaveToVarUI)
ParamSaveVarName := MyGui.Add("Text", "x15 y210 hidden", "变量名：")
InputSaveVarName := MyGui.Add("Edit", "x90 y208 w200 hidden", "LoopCount_OCR")

ParamFillX := MyGui.Add("Text", "x15 y210 hidden", "填入X：")
InputFillX := MyGui.Add("Edit", "x70 y208 w50 hidden")
ParamFillY := MyGui.Add("Text", "x130 y210 hidden", "Y：")
InputFillY := MyGui.Add("Edit", "x150 y208 w50 hidden")
BtnGetFillPos := MyGui.Add("Button", "x210 y207 w80 hidden", "获取坐标")
BtnGetFillPos.OnEvent("Click", GetFillPos)

ParamFillX2 := MyGui.Add("Text", "x15 y245 hidden", "目标2 X：")
InputFillX2 := MyGui.Add("Edit", "x80 y243 w50 hidden")
ParamFillY2 := MyGui.Add("Text", "x140 y245 hidden", "Y：")
InputFillY2 := MyGui.Add("Edit", "x160 y243 w50 hidden")
BtnGetFillPos2 := MyGui.Add("Button", "x220 y242 w80 hidden", "获取坐标")
BtnGetFillPos2.OnEvent("Click", GetFillPos2)

ParamFillX3 := MyGui.Add("Text", "x15 y280 hidden", "目标3 X：")
InputFillX3 := MyGui.Add("Edit", "x80 y278 w50 hidden")
ParamFillY3 := MyGui.Add("Text", "x140 y280 hidden", "Y：")
InputFillY3 := MyGui.Add("Edit", "x160 y278 w50 hidden")
BtnGetFillPos3 := MyGui.Add("Button", "x220 y277 w80 hidden", "获取坐标")
BtnGetFillPos3.OnEvent("Click", GetFillPos3)

; ============ 范围随机 ============
ParamDecimal := MyGui.Add("Text", "x15 y90 w55 hidden", "小数位：")
DecimalDDL := MyGui.Add("DropDownList", "x75 y88 w90 hidden", ["整数", "1位小数", "2位小数", "3位小数"])
DecimalDDL.Value := 1
ChkEven := MyGui.Add("CheckBox", "x175 y90 w110 hidden", "尾数为偶数") 
ParamRDB := MyGui.Add("Text", "x15 y120 w70 hidden", "范围CSV：")
RandDBPath := MyGui.Add("Edit", "x90 y118 w220 hidden ReadOnly", "DataMap_Range.csv")
RandBtnDB := MyGui.Add("Button", "x315 y117 w55 hidden", "选表")
RandBtnDB.OnEvent("Click", SelectRandDB)
RandBtnGen := MyGui.Add("Button", "x375 y117 w55 hidden", "模板")
RandBtnGen.OnEvent("Click", GenerateRandDBTemplate)
ParamRPosDB := MyGui.Add("Text", "x15 y150 w70 hidden", "坐标CSV：")
RPosDBPath := MyGui.Add("Edit", "x90 y148 w220 hidden ReadOnly", "Positions.csv")
RPosBtnDB := MyGui.Add("Button", "x315 y147 w55 hidden", "选表")
RPosBtnDB.OnEvent("Click", SelectRPosDB)
RPosBtnGen := MyGui.Add("Button", "x375 y147 w55 hidden", "模板")
RPosBtnGen.OnEvent("Click", GenerateRPosDBTemplate)
RandHint := MyGui.Add("Text", "x15 y180 w600 hidden", "坐标CSV 每行 x,y，行数即填写组数（1~N 任意）")

; ============ 坐标查表 ============
ParamMultiDB := MyGui.Add("Text", "x15 y90 w70 hidden", "数据CSV：")
MultiDBPath := MyGui.Add("Edit", "x90 y88 w220 hidden ReadOnly", "MultiMap.csv")
MultiBtnDB := MyGui.Add("Button", "x315 y87 w55 hidden", "选表")
MultiBtnDB.OnEvent("Click", (*) => MultiDBPath.Value := FileSelect(3, A_ScriptDir, "选择数据CSV", "CSV文件 (*.csv)"))
MultiBtnGen := MyGui.Add("Button", "x375 y87 w55 hidden", "模板")
MultiBtnGen.OnEvent("Click", GenerateMultiDBTemplate)
ParamMultiType := MyGui.Add("Text", "x15 y150 w70 hidden", "匹配依据：")
MultiTypeDDL := MyGui.Add("DropDownList", "x90 y148 w150 hidden", ["用OCR原文匹配", "用包含文字匹配"])
MultiTypeDDL.Value := 1
MultiHint := MyGui.Add("Text", "x15 y180 w600 hidden", "格式：关键词, X1, Y1, 内容1, X2, Y2, 内容2, ...")

; ============ 条件跳过（支持变量匹配） ============
ParamSkipBasis := MyGui.Add("Text", "x440 y25 w70 hidden", "判断依据：")
SkipBasisDDL := MyGui.Add("DropDownList", "x510 y23 w130 hidden", ["颜色", "OCR文字", "变量匹配"])
SkipBasisDDL.Value := 1
SkipBasisDDL.OnEvent("Change", ChangeSkipBasis)

ParamSkipColorX := MyGui.Add("Text", "x15 y60 hidden", "X坐标：")
InputSkipColorX := MyGui.Add("Edit", "x70 y58 w50 hidden")
ParamSkipColorY := MyGui.Add("Text", "x130 y60 hidden", "Y坐标：")
InputSkipColorY := MyGui.Add("Edit", "x180 y58 w50 hidden")
BtnSkipColorGet := MyGui.Add("Button", "x240 y57 w90 hidden", "获取坐标+色")
BtnSkipColorGet.OnEvent("Click", GetSkipColorPos)
ParamSkipColor := MyGui.Add("Text", "x340 y60 hidden", "颜色值：")
InputSkipColor := MyGui.Add("Edit", "x400 y58 w80 hidden", "FF0000")

ParamSkipOcrArea := MyGui.Add("Text", "x15 y60 hidden", "识别区域：")
InputSkipOcrArea := MyGui.Add("Edit", "x90 y58 w200 hidden ReadOnly", "未选择区域")
BtnSkipSelectArea := MyGui.Add("Button", "x300 y57 w80 hidden", "框选区域")
BtnSkipSelectArea.OnEvent("Click", SelectSkipOcrArea)
ParamSkipKeyword := MyGui.Add("Text", "x15 y90 hidden", "包含文字：")
InputSkipKeyword := MyGui.Add("Edit", "x90 y88 w150 hidden")

; 变量匹配 通用控件
ParamVarMatchName := MyGui.Add("Text", "x15 y60 w70 hidden", "变量名：")
InputVarMatchName := MyGui.Add("Edit", "x90 y58 w150 hidden", "CurrentLoop")
VarMatchHint := MyGui.Add("Text", "x250 y60 w350 hidden", "(系统内置: CurrentLoop=当前循环次数)")
ParamLoopCompareOp := MyGui.Add("Text", "x15 y90 w70 hidden", "比较符：")
LoopCompareOpDDL := MyGui.Add("DropDownList", "x90 y88 w100 hidden", ["==", "!=", ">", "<", ">=", "<=", "包含", "是N的倍数"])
LoopCompareOpDDL.Value := 1
ParamLoopCompareVal := MyGui.Add("Text", "x200 y90 w70 hidden", "目标值：")
InputLoopCompareVal := MyGui.Add("Edit", "x270 y88 w100 hidden", "1")

ParamSkipAction := MyGui.Add("Text", "x15 y120 hidden", "动作：")
SkipActionDDL := MyGui.Add("DropDownList", "x70 y118 w200 hidden", ["匹配 → 跳过N步", "不匹配 → 跳过N步", "匹配 → 彻底停止"])
SkipActionDDL.Value := 1
ParamSkip := MyGui.Add("Text", "x290 y120 hidden", "N：")
InputSkip := MyGui.Add("Edit", "x320 y118 w50 hidden", "1")

; ============ 局部循环开始 ============
ParamLoopSrc := MyGui.Add("Text", "x15 y60 w70 hidden", "次数来源：")
LoopSrcDDL := MyGui.Add("DropDownList", "x90 y58 w150 hidden", ["固定值", "变量"])
LoopSrcDDL.Value := 1
LoopSrcDDL.OnEvent("Change", UpdateLoopSrcUI)
ParamInnerLoop := MyGui.Add("Text", "x15 y90 hidden", "循环次数：")
InputInnerLoop := MyGui.Add("Edit", "x90 y88 w80 hidden", "3")
ParamLoopVarName := MyGui.Add("Text", "x15 y90 hidden", "变量名：")
InputLoopVarName := MyGui.Add("Edit", "x90 y88 w180 hidden", "LoopCount_OCR")

; ============ 条件分支 (If)（支持变量匹配） ============
ParamIfType := MyGui.Add("Text", "x340 y25 w60 hidden", "判断条件:")
IfTypeDDL := MyGui.Add("DropDownList", "x405 y23 w130 hidden", ["OCR包含文字", "颜色匹配", "变量匹配"])
IfTypeDDL.Value := 1
IfTypeDDL.OnEvent("Change", ChangeIfType)

; ============ 设置变量 ============
ParamSetVarName := MyGui.Add("Text", "x15 y60 hidden", "变量名：")
InputSetVarName := MyGui.Add("Edit", "x90 y58 w180 hidden", "MyVar")
ParamSetVarValue := MyGui.Add("Text", "x15 y90 hidden", "值(支持{Var})：")
InputSetVarValue := MyGui.Add("Edit", "x120 y88 w350 hidden")

; ============ 调用子脚本 ============
ParamSubScript := MyGui.Add("Text", "x15 y60 w70 hidden", "子脚本：")
InputSubScript := MyGui.Add("Edit", "x90 y58 w210 hidden", "")
BtnSelSubScript := MyGui.Add("Button", "x305 y57 w70 hidden", "📂 浏览")
BtnSelSubScript.OnEvent("Click", SelectSubScript)
BtnPastePath := MyGui.Add("Button", "x380 y57 w100 hidden", "📋 粘贴路径")
BtnPastePath.OnEvent("Click", PastePathFromClipboard)

ParamSubArgs := MyGui.Add("Text", "x15 y90 w70 hidden", "参数：")
InputSubArgs := MyGui.Add("Edit", "x90 y88 w400 hidden", "")
ParamSubArgsHint := MyGui.Add("Text", "x15 y120 w650 hidden", "支持 {变量} 插值；含空格请用双引号包裹。结果文件路径由主脚本自动追加为最后一个参数。")

ParamSubWaitMode := MyGui.Add("Text", "x15 y150 w70 hidden", "等待模式：")
SubWaitModeDDL := MyGui.Add("DropDownList", "x90 y148 w100 hidden", ["阻塞", "不等待"])
SubWaitModeDDL.Value := 1
SubWaitModeDDL.OnEvent("Change", UpdateSubWaitUI)
ParamSubTimeout := MyGui.Add("Text", "x210 y150 w70 hidden", "超时(秒)：")
InputSubTimeout := MyGui.Add("Edit", "x290 y148 w60 hidden", "0")
ParamSubTimeoutHint := MyGui.Add("Text", "x360 y150 w300 hidden", "(0=不限；超时强制结束子脚本)")

ParamSubResultVar := MyGui.Add("Text", "x15 y180 w110 hidden", "结果存入变量：")
InputSubResultVar := MyGui.Add("Edit", "x130 y178 w180 hidden", "")
ParamSubResultVarHint := MyGui.Add("Text", "x320 y180 w340 hidden", "(可空；子脚本写 value 时自动回读)")

ParamSubResultFile := MyGui.Add("Text", "x15 y210 w110 hidden", "结果文件：")
InputSubResultFile := MyGui.Add("Edit", "x130 y208 w400 hidden", "")
ParamSubResultFileHint := MyGui.Add("Text", "x15 y240 w650 hidden", "(可空=自动用 %Temp%\subresult_*.ini)")

; ============ 🔍 OCR识别保存文本 ============
ParamOcrSaveTxtArea := MyGui.Add("Text", "x15 y60 hidden", "识别区域：")
InputOcrSaveTxtArea := MyGui.Add("Edit", "x90 y58 w200 hidden ReadOnly", "未选择区域")
BtnOcrSaveTxtSelectArea := MyGui.Add("Button", "x300 y57 w80 hidden", "框选区域")
BtnOcrSaveTxtSelectArea.OnEvent("Click", SelectOcrSaveTxtArea)

ParamExtractMode := MyGui.Add("Text", "x15 y90 hidden", "提取方式：")
ExtractModeDDL := MyGui.Add("DropDownList", "x90 y88 w140 hidden", ["全部文本", "第N项", "首个匹配正则", "全部匹配正则"])
ExtractModeDDL.Value := 1

ParamExtractN := MyGui.Add("Text", "x240 y90 hidden", "N=")
InputExtractN := MyGui.Add("Edit", "x265 y88 w40 hidden", "1")

ParamFilterRe := MyGui.Add("Text", "x320 y90 hidden", "过滤/提取正则：")
InputFilterRe := MyGui.Add("Edit", "x430 y88 w200 hidden")

ParamDelimiter := MyGui.Add("Text", "x15 y120 hidden", "分隔符：")
DelimiterDDL := MyGui.Add("DropDownList", "x90 y118 w110 hidden", ["换行", "逗号", "空格", "制表符"])
DelimiterDDL.Value := 1

ParamSaveTxtVar := MyGui.Add("Text", "x220 y120 hidden", "保存到变量：")
InputSaveTxtVar := MyGui.Add("Edit", "x310 y118 w180 hidden", "OCRText")

; ============ 🎯 匹配文本并点击 ============
ParamOcrMatchTxtArea := MyGui.Add("Text", "x15 y60 hidden", "识别区域：")
InputOcrMatchTxtArea := MyGui.Add("Edit", "x90 y58 w200 hidden ReadOnly", "未选择区域")
BtnOcrMatchTxtSelectArea := MyGui.Add("Button", "x300 y57 w80 hidden", "框选区域")
BtnOcrMatchTxtSelectArea.OnEvent("Click", SelectOcrMatchTxtArea)

ParamMatchTxtKeyword := MyGui.Add("Text", "x15 y90 hidden", "匹配内容：")
InputMatchTxtKeyword := MyGui.Add("Edit", "x90 y88 w200 hidden", "{OCRText}")
ParamMatchTxtHint := MyGui.Add("Text", "x300 y90 w400 hidden", "(支持 {变量} 插值；变量来自 识别保存文本)")

ParamMatchTxtMode := MyGui.Add("Text", "x15 y120 hidden", "匹配方式：")
MatchTxtModeDDL := MyGui.Add("DropDownList", "x90 y118 w110 hidden", ["包含", "完全等于", "正则"])
MatchTxtModeDDL.Value := 1

ParamMatchTxtStrategy := MyGui.Add("Text", "x220 y120 hidden", "策略：")
MatchTxtStrategyDDL := MyGui.Add("DropDownList", "x270 y118 w110 hidden", ["第一个", "全部", "第N个"])
MatchTxtStrategyDDL.Value := 1

ParamMatchTxtN := MyGui.Add("Text", "x400 y120 hidden", "N=")
InputMatchTxtN := MyGui.Add("Edit", "x425 y118 w40 hidden", "1")

ParamMatchTxtPos := MyGui.Add("Text", "x15 y150 hidden", "点击位置：")
MatchTxtPosDDL := MyGui.Add("DropDownList", "x90 y148 w130 hidden", ["文字中心", "左上角", "右下角", "右侧中点"])
MatchTxtPosDDL.Value := 1

ParamMatchTxtOffX := MyGui.Add("Text", "x240 y150 hidden", "X偏移：")
InputMatchTxtOffX := MyGui.Add("Edit", "x300 y148 w50 hidden", "0")
ParamMatchTxtOffY := MyGui.Add("Text", "x360 y150 hidden", "Y偏移：")
InputMatchTxtOffY := MyGui.Add("Edit", "x415 y148 w50 hidden", "0")

ParamMatchTxtAction := MyGui.Add("Text", "x15 y180 hidden", "动作：")
MatchTxtActionDDL := MyGui.Add("DropDownList", "x70 y178 w130 hidden", ["点击", "仅移动不点击"])
MatchTxtActionDDL.Value := 1

ParamMatchTxtWait := MyGui.Add("Text", "x220 y180 hidden", "等待出现(秒)：")
InputMatchTxtWait := MyGui.Add("Edit", "x330 y178 w60 hidden", "0")
ParamMatchTxtWaitHint := MyGui.Add("Text", "x400 y180 w250 hidden", "(0=只搜一次；>0=循环等)")

; ============ 备注 ============
MyGui.Add("Text", "x490 y360 w40", "备注：") 
InputRemark := MyGui.Add("Edit", "x530 y358 w150", "") 

; ============ 全局设置 ============
ParamFailPolicy := MyGui.Add("Text", "x15 y390 w70", "失败策略：")
FailPolicyDDL := MyGui.Add("DropDownList", "x90 y388 w180", ["立即停止", "跳过继续", "重试1次后停止", "重试3次后停止"])
FailPolicyDDL.Value := 1
FailPolicyDDL.OnEvent("Change", ChangeFailPolicy)
ChkLogEnable := MyGui.Add("CheckBox", "x290 y390 w90", "启用日志")
ChkLogEnable.OnEvent("Click", UpdateLogUI)
ParamLogPath := MyGui.Add("Text", "x390 y390 w50 hidden", "路径：")
InputLogPath := MyGui.Add("Edit", "x440 y388 w180 hidden ReadOnly", "run.log")
BtnLogPath := MyGui.Add("Button", "x625 y387 w60 hidden", "选...")
BtnLogPath.OnEvent("Click", SelectLogPath)

; --- 中间任务列表区 ---
MidGroup := MyGui.Add("GroupBox", "xm y+20 w700 h290", "任务队列（按顺序执行）")
LV := MyGui.Add("ListView", "xm+10 yp+20 w680 h260 -Multi", ["序号", "任务类型", "参数详情", "备注"])
LV.ModifyCol(1, 45), LV.ModifyCol(2, 110), LV.ModifyCol(3, 380), LV.ModifyCol(4, 120)
LV.OnEvent("DoubleClick", OnTaskDoubleClick)

; --- 底部控制区 ---
TextLoopCount := MyGui.Add("Text", "xm y+10", "外层总循环(0为无限)：")
InputLoopCount := MyGui.Add("Edit", "x+5 yp-3 w40", "1")
BtnAdd := MyGui.Add("Button", "x+15 yp-2 w90 h30", "添加到末尾")
BtnAdd.OnEvent("Click", (*) => AddTask(False))
BtnInsert := MyGui.Add("Button", "x+10 yp w120 h30 Default", "插入到选中位置")
BtnInsert.OnEvent("Click", (*) => AddTask(True))
BtnRun := MyGui.Add("Button", "x+20 yp w100 h30", "▶ 开始执行")
BtnRun.OnEvent("Click", BtnRunHandler)
BtnRunFrom := MyGui.Add("Button", "x+10 yp w105 h30", "▶ 从选中开始")
BtnRunFrom.OnEvent("Click", BtnRunFromHandler)
BtnExport := MyGui.Add("Button", "x+10 yp w105 h30", "📤 导出独立脚本")
BtnExport.OnEvent("Click", ExportToAhkSafe)

BtnDel := MyGui.Add("Button", "xm y+10 w75 h30", "删除选中")
BtnDel.OnEvent("Click", DeleteTask)
BtnEdit := MyGui.Add("Button", "x+10 yp w95 h30", "✏ 编辑选中")
BtnEdit.OnEvent("Click", BtnEditHandler)
BtnCancelEdit := MyGui.Add("Button", "x+10 yp w95 h30 hidden", "❌ 取消编辑")
BtnCancelEdit.OnEvent("Click", CancelEdit)
BtnUp := MyGui.Add("Button", "x+10 yp w55 h30", "↑ 上移")
BtnUp.OnEvent("Click", MoveUp)
BtnDown := MyGui.Add("Button", "x+10 yp w55 h30", "↓ 下移")
BtnDown.OnEvent("Click", MoveDown)
BtnClear := MyGui.Add("Button", "x+10 yp w75 h30", "清空列表")
BtnClear.OnEvent("Click", ClearAll)
BtnSave := MyGui.Add("Button", "x+10 yp w95 h30", "💾 保存配置")
BtnSave.OnEvent("Click", SaveConfig)
BtnLoad := MyGui.Add("Button", "x+10 yp w95 h30", "📂 读取配置")
BtnLoad.OnEvent("Click", LoadConfig)

StatusBar := MyGui.Add("StatusBar")
StatusBar.SetText("就绪 | F3 暂停/继续   F2 终止   F4 退出")

MyGui.OnEvent("Close", (*) => ExitApp())
MyGui.OnEvent("Size", GuiSize)
OnMessage(0x0233, WM_DROPFILES)
MyGui.Show("w720 h960")
ChangeType()

; ================= 🛑 热键 =================
F3:: {
    global IsPaused
    IsPaused := !IsPaused
    if (IsPaused) {
        ToolTip("⏸️ 任务已暂停", 10, 10)
    } else {
        ToolTip("▶ 任务继续", 10, 10)
    }
}
F2:: {
    global IsStopped, IsPaused
    if (IsStopped) {
        return
    }
    IsStopped := true, IsPaused := false
    ToolTip("⏹ 已中断", 10, 10)
    SetTimer(() => ToolTip(), -3000)
}
F4:: ExitApp

; ================= 基础辅助函数 =================
SmartSleep(ms) {
    global IsPaused, IsStopped
    startTime := A_TickCount
    while (A_TickCount - startTime < ms) {
        if (IsStopped) {
            return
        }
        if (IsPaused) {
            while (IsPaused) {
                if (IsStopped) {
                    return
                }
                Sleep(50)
            }
        }
        Sleep(20)
    }
}

Interpolate(str) {
    global VarPool
    if (str == "")
        return str
    out := str
    Loop 5 {
        pos := 1
        built := ""
        while (RegExMatch(out, "\{([A-Za-z_]\w*)\}", &m, pos)) {
            varName := m[1]
            built .= SubStr(out, pos, m.Pos - pos)
            if (VarPool.Has(varName)) {
                built .= VarPool[varName]
            } else {
                built .= m[0]
            }
            pos := m.Pos + m.Len
        }
        built .= SubStr(out, pos)
        if (built == out)
            break
        out := built
    }
    return out
}

CompareValue(val1, val2, op) {
    if (op == "包含")
        return InStr(val1, val2) ? true : false
    if (op == "是N的倍数") {
        if (IsNumber(val1) && IsNumber(val2) && (val2 + 0 != 0))
            return Mod(val1 + 0, val2 + 0) == 0
        return false
    }
    
    if (IsNumber(val1) && IsNumber(val2)) {
        v1 := val1 + 0, v2 := val2 + 0
        switch op {
            case "==": return v1 == v2
            case "!=": return v1 != v2
            case ">":  return v1 > v2
            case "<":  return v1 < v2
            case ">=": return v1 >= v2
            case "<=": return v1 <= v2
        }
    } else {
        switch op {
            case "==": return val1 == val2
            case "!=": return val1 != val2
            default: return false
        }
    }
    return false
}

LogWrite(msg) {
    global LogEnabled, LogPath
    if (!LogEnabled)
        return
    try {
        FileAppend("[" FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") "] " msg "`n", LogPath, "UTF-8")
    }
}

OCR_Region(x, y, w, h) {
    tmpImg := A_Temp . "\OCR_" . A_TickCount . "_" . Random(1000, 9999) . ".bmp"
    CaptureAreaFile(x, y, w, h, tmpImg)
    txt := DoOCR_File(tmpImg)
    try FileDelete(tmpImg)
    return Trim(txt)
}

LoadCoordsCSV(path) {
    global CSVCache
    if (CSVCache.Coords.Has(path))
        return CSVCache.Coords[path]
    coords := []
    if (!FileExist(path))
        return coords
    for _, line in StrSplit(FileRead(path, "UTF-8"), Chr(10), Chr(13)) {
        parts := StrSplit(line, ",")
        if (parts.Length >= 2) {
            sx := Trim(parts[1]), sy := Trim(parts[2])
            if (IsNumber(sx) && IsNumber(sy))
                coords.Push([Integer(sx), Integer(sy)])
        }
    }
    CSVCache.Coords[path] := coords
    return coords
}

LoadKeyValuesCSV(path) {
    global CSVCache
    if (CSVCache.KeyValues.Has(path))
        return CSVCache.KeyValues[path]
    result := Map()
    if (!FileExist(path))
        return result
    rawText := FileRead(path, "UTF-8")
    if (SubStr(rawText, 1, 1) == Chr(0xFEFF))
        rawText := SubStr(rawText, 2)
    for _, line in StrSplit(rawText, Chr(10), Chr(13)) {
        line := Trim(line)
        if (line == "")
            continue
        sep := InStr(line, ",") ? "," : (InStr(line, Chr(9)) ? Chr(9) : ",")
        parts := StrSplit(line, sep)
        if (parts.Length < 2)
            continue
        key := Trim(parts[1])
        vals := []
        Loop parts.Length - 1 {
            v := Trim(parts[A_Index + 1])
            if (v != "")
                vals.Push(v)
        }
        if (key != "" && !result.Has(key))
            result[key] := vals
    }
    CSVCache.KeyValues[path] := result
    return result
}

; 多坐标查表：按 key 命中后返回 [{x,y,value}, ...]，带 CSVCache 缓存
LoadMultiMapCSV(path) {
    global CSVCache
    if (!CSVCache.Has("MultiMap"))
        CSVCache["MultiMap"] := Map()
    if (CSVCache["MultiMap"].Has(path))
        return CSVCache["MultiMap"][path]
    result := Map()
    if (!FileExist(path))
        return result
    rawText := FileRead(path, "UTF-8")
    if (SubStr(rawText, 1, 1) == Chr(0xFEFF))
        rawText := SubStr(rawText, 2)
    for _, line in StrSplit(rawText, Chr(10), Chr(13)) {
        line := Trim(line)
        if (line == "")
            continue
        sep := InStr(line, ",") ? "," : (InStr(line, Chr(9)) ? Chr(9) : ",")
        parts := StrSplit(line, sep)
        if (parts.Length < 4)
            continue
        key := Trim(parts[1])
        if (key == "" || result.Has(key))
            continue
        targets := []
        i := 2
        while (i + 2 <= parts.Length) {
            sx := Trim(parts[i]), sy := Trim(parts[i+1])
            tVal := Trim(parts[i+2])
            if (IsNumber(sx) && IsNumber(sy) && tVal != "")
                targets.Push({x: Integer(sx), y: Integer(sy), value: tVal})
            i += 3
        }
        if (targets.Length > 0)
            result[key] := targets
    }
    CSVCache["MultiMap"][path] := result
    return result
}

HandleFail(stepIP, stepType, errMsg) {
    global FailPolicy, IsStopped, g_RetryCounter, SilentMode
    LogWrite("FAIL 步骤" stepIP " | " stepType " | " errMsg)
    cur := g_RetryCounter.Has(stepIP) ? g_RetryCounter[stepIP] : 0
    switch FailPolicy {
        case "skip":
            ToolTip("⚠️ 步骤" stepIP "失败，跳过：" errMsg, 10, 10)
            Sleep(800)
            return "skip"
        case "retry1stop":
            if (cur < 1) {
                g_RetryCounter[stepIP] := cur + 1
                ToolTip("⚠️ 步骤" stepIP "失败，重试中：" errMsg, 10, 10)
                Sleep(800)
                return "retry"
            }
            if (!SilentMode)
                MsgBox("步骤" stepIP " 重试1次后仍失败：`n" errMsg, "失败", "Iconx")
            IsStopped := true
            return "stop"
        case "retry3stop":
            if (cur < 3) {
                g_RetryCounter[stepIP] := cur + 1
                ToolTip("⚠️ 步骤" stepIP "失败，重试 " (cur+1) "/3：" errMsg, 10, 10)
                Sleep(800)
                return "retry"
            }
            if (!SilentMode)
                MsgBox("步骤" stepIP " 重试3次后仍失败：`n" errMsg, "失败", "Iconx")
            IsStopped := true
            return "stop"
        default:
            if (!SilentMode)
                MsgBox("步骤" stepIP " 失败：`n" errMsg, "失败", "Iconx")
            IsStopped := true
            return "stop"
    }
}

GetImageSize(path) {
    SplitPath(path, , , &ext)
    ext := StrLower(ext)
    f := 0
    try f := FileOpen(path, "r")
    catch
        return [0, 0]
    if (!f)
        return [0, 0]
    try {
        if (ext == "bmp") {
            buf := Buffer(30, 0)
            f.RawRead(buf, 30)
            return [Abs(NumGet(buf, 18, "Int")), Abs(NumGet(buf, 22, "Int"))]
        } else if (ext == "png") {
            buf := Buffer(24, 0)
            f.RawRead(buf, 24)
            return [NumGet(buf, 16, "UInt"), NumGet(buf, 20, "UInt")]
        } else if (ext == "gif") {
            buf := Buffer(10, 0)
            f.RawRead(buf, 10)
            return [NumGet(buf, 6, "UShort"), NumGet(buf, 8, "UShort")]
        }
    } catch {
    } finally {
        f.Close()
    }
    return [0, 0]
}

GuiSize(thisGui, MinMax, Width, Height) {
    if (MinMax = -1 || Width < 720)
        return
    topHeight := 450, bottomHeight := 140
    midHeight := Height - topHeight - bottomHeight - 30
    if (midHeight < 100)
        midHeight := 100
    MidGroup.Move(10, topHeight, Width - 20, midHeight)
    LV.Move(20, topHeight + 20, Width - 40, midHeight - 30)
    bottomY1 := topHeight + midHeight + 10
    TextLoopCount.Move(10, bottomY1 + 3), InputLoopCount.Move(130, bottomY1)
    BtnAdd.Move(185, bottomY1, 80, 30), BtnInsert.Move(270, bottomY1, 105, 30), BtnRun.Move(380, bottomY1, 95, 30), BtnRunFrom.Move(480, bottomY1, 105, 30), BtnExport.Move(590, bottomY1, 105, 30)
    bottomY2 := bottomY1 + 40
    BtnDel.Move(10, bottomY2, 75, 30)
    BtnUp.Move(95, bottomY2, 55, 30)
    BtnDown.Move(160, bottomY2, 55, 30)
    BtnClear.Move(225, bottomY2, 75, 30)
    BtnEdit.Move(310, bottomY2, 95, 30)
    BtnCancelEdit.Move(415, bottomY2, 95, 30)
    BtnSave.Move(520, bottomY2, 90, 30)
    BtnLoad.Move(620, bottomY2, 90, 30)
}

; ================= 截图与 OCR 底层 =================
SelectRegion() {
    CaptureGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80000")
    CaptureGui.BackColor := "000000", WinSetTransparent(100, CaptureGui)
    CaptureGui.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight)
    BoxGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    BoxGui.BackColor := "FF0000", WinSetTransparent(80, BoxGui)
    DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32515, "Ptr"))
    KeyWait("LButton"), Sleep(100), KeyWait("LButton", "D"), MouseGetPos(&startX, &startY)
    while GetKeyState("LButton", "P") {
        MouseGetPos(&curX, &curY)
        w := Abs(curX - startX), h := Abs(curY - startY)
        x := Min(curX, startX), y := Min(curY, startY)
        if (w > 5 && h > 5)
            BoxGui.Show("x" x " y" y " w" w " h" h " NoActivate")
        Sleep(10)
    }
    MouseGetPos(&endX, &endY)
    w := Abs(endX - startX), h := Abs(endY - startY)
    x := Min(endX, startX), y := Min(endY, startY)
    CaptureGui.Destroy(), BoxGui.Destroy()
    if (w > 5 && h > 5) {
        SaveDir := A_ScriptDir "\Screenshots"
        if (!DirExist(SaveDir))
            DirCreate(SaveDir)
        SavePath := SaveDir "\Capture_" A_TickCount ".bmp"
        if (CaptureAreaFile(x, y, w, h, SavePath))
            return {path: SavePath, x: x, y: y, w: w, h: h}
    }
    return ""
}

CaptureAreaFile(x, y, w, h, filePath) {
    hDC := DllCall("GetDC", "Ptr", 0, "Ptr"), hMemDC := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
    hBmp := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", w, "Int", h)
    DllCall("SelectObject", "Ptr", hMemDC, "Ptr", hBmp)
    DllCall("BitBlt", "Ptr", hMemDC, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hDC, "Int", x, "Int", y, "UInt", 0x00CC0020)
    bmi := Buffer(40, 0)
    NumPut("UInt", 40, bmi, 0), NumPut("Int", w, bmi, 4), NumPut("Int", -h, bmi, 8), NumPut("Short", 1, bmi, 12), NumPut("Short", 24, bmi, 14)
    rowSize := Ceil(w * 3 / 4) * 4, imgSize := rowSize * h
    imgData := Buffer(imgSize, 0)
    DllCall("GetDIBits", "Ptr", hMemDC, "Ptr", hBmp, "UInt", 0, "UInt", h, "Ptr", imgData, "Ptr", bmi, "UInt", 0)
    fileHeader := Buffer(14, 0)
    NumPut("UShort", 0x4D42, fileHeader, 0), NumPut("UInt", 14 + 40 + imgSize, fileHeader, 2), NumPut("UInt", 14 + 40, fileHeader, 10)
    File := FileOpen(filePath, "w"), File.RawWrite(fileHeader, 14), File.RawWrite(bmi, 40), File.RawWrite(imgData, imgSize), File.Close()
    DllCall("DeleteObject", "Ptr", hBmp), DllCall("DeleteDC", "Ptr", hMemDC), DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
    return FileExist(filePath)
}

DoOCR_File(ImagePath) {
        try {
            FileData := FileRead(ImagePath, "RAW")
            Size := 0
            DllCall("Crypt32.dll\CryptBinaryToStringW", "Ptr", FileData.Ptr, "UInt", FileData.Size, "UInt", 1, "Ptr", 0, "UInt*", &Size)
            Base64Buf := Buffer(Size * 2)
            DllCall("Crypt32.dll\CryptBinaryToStringW", "Ptr", FileData.Ptr, "UInt", FileData.Size, "UInt", 1, "Ptr", Base64Buf, "UInt*", &Size)
            B64Str := StrGet(Base64Buf, "UTF-16")
            B64Str := StrReplace(StrReplace(B64Str, Chr(13), ""), Chr(10), "")

            payload := "{" . Chr(34) . "base64" . Chr(34) . ": " . Chr(34) . B64Str . Chr(34) . "}"

            tmpReq := A_Temp . "\OCR_Req_" . A_TickCount . "_" . Random(1000, 9999) . ".json"
            tmpRes := A_Temp . "\OCR_Res_" . A_TickCount . "_" . Random(1000, 9999) . ".json"
            FileAppend(payload, tmpReq, "UTF-8-RAW")
            Sleep(50)

            curlPath := ""
            for _, candidate in [
                A_ScriptDir "\curl.exe",
                A_ScriptDir "\curl-8.23.0_1-win64-mingw\bin\curl.exe",
                A_WinDir "\System32\curl.exe",
                A_WinDir "\Sysnative\curl.exe",
                "curl.exe"
            ] {
                if FileExist(candidate) {
                    curlPath := candidate
                    break
                }
            }
            if (curlPath == "") {
                LogWrite("❌ DoOCR_File: 未找到 curl.exe")
                ToolTip("❌ OCR 引擎缺失：未找到 curl.exe", 10, 10)
                SetTimer(() => ToolTip(), -3000)
                try FileDelete(tmpReq)
                return ""
            }

            cmd := Chr(34) . curlPath . Chr(34) . " -m 15 -s -X POST " . Chr(34) . "http://127.0.0.1:1224/api/ocr" . Chr(34) . " -H " . Chr(34) . "Content-Type: application/json" . Chr(34) . " --data-binary " . Chr(34) . "@" . tmpReq . Chr(34) . " -o " . Chr(34) . tmpRes . Chr(34)
            RunWait(cmd, A_Temp, "Hide")

            respText := ""
            if (FileExist(tmpRes)) {
                respText := FileRead(tmpRes, "UTF-8")
                FileDelete(tmpRes)
            }
            FileDelete(tmpReq)

            if (respText != "") {
                result := "", pos := 1
                while (RegExMatch(SubStr(respText, pos), '"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)) {
                    textChunk := m[1]
                    textChunk := _DecodeUnicode(textChunk)
                    result .= textChunk
                    pos := pos + m.Pos - 1 + m.Len
                }
                return Trim(result)
            }
            return ""
        } catch {
            return ""
    }
}

; ===== 解析 OCR JSON，返回 [{text, box, x, y, w, h, cx, cy}, ...] =====
DoOCR_File_Detailed(ImagePath) {
    try {
        FileData := FileRead(ImagePath, "RAW")
        Size := 0
        DllCall("Crypt32.dll\CryptBinaryToStringW", "Ptr", FileData.Ptr, "UInt", FileData.Size, "UInt", 1, "Ptr", 0, "UInt*", &Size)
        Base64Buf := Buffer(Size * 2)
        DllCall("Crypt32.dll\CryptBinaryToStringW", "Ptr", FileData.Ptr, "UInt", FileData.Size, "UInt", 1, "Ptr", Base64Buf, "UInt*", &Size)
        B64Str := StrGet(Base64Buf, "UTF-16")
        B64Str := StrReplace(StrReplace(B64Str, Chr(13), ""), Chr(10), "")
        payload := "{" . Chr(34) . "base64" . Chr(34) . ": " . Chr(34) . B64Str . Chr(34) . "}"
        tmpReq := A_Temp . "\OCR_Req_" . A_TickCount . "_" . Random(1000, 9999) . ".json"
        tmpRes := A_Temp . "\OCR_Res_" . A_TickCount . "_" . Random(1000, 9999) . ".json"
        FileAppend(payload, tmpReq, "UTF-8-RAW")
        Sleep(50)
        curlPath := ""
        for _, c in [A_ScriptDir "\curl.exe",
                     A_ScriptDir "\curl-8.23.0_1-win64-mingw\bin\curl.exe",
                     A_WinDir "\System32\curl.exe",
                     A_WinDir "\Sysnative\curl.exe",
                     "curl.exe"] {
            if FileExist(c) {
                curlPath := c
                break
            }
        }
        if (curlPath == "") {
            try FileDelete(tmpReq)
            return []
        }
        cmd := Chr(34) . curlPath . Chr(34) . " -m 15 -s -X POST " . Chr(34) . "http://127.0.0.1:1224/api/ocr" . Chr(34) . " -H " . Chr(34) . "Content-Type: application/json" . Chr(34) . " --data-binary " . Chr(34) . "@" . tmpReq . Chr(34) . " -o " . Chr(34) . tmpRes . Chr(34)
        RunWait(cmd, A_Temp, "Hide")
        respText := ""
        if (FileExist(tmpRes)) {
            respText := FileRead(tmpRes, "UTF-8")
            FileDelete(tmpRes)
        }
        FileDelete(tmpReq)
        if (respText == "")
            return []
        texts := []
        pos := 1
        while (RegExMatch(SubStr(respText, pos), '"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)) {
            texts.Push(_DecodeUnicode(m[1]))
            pos := pos + m.Pos - 1 + m.Len
        }
        boxes := []
        pos := 1
        while (RegExMatch(SubStr(respText, pos),
            '"box"\s*:\s*\[\s*\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]\s*,\s*\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]\s*,\s*\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]\s*,\s*\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]\s*\]', &m)) {
            boxes.Push([[Integer(m[1]), Integer(m[2])],
                        [Integer(m[3]), Integer(m[4])],
                        [Integer(m[5]), Integer(m[6])],
                        [Integer(m[7]), Integer(m[8])]])
            pos := pos + m.Pos - 1 + m.Len
        }
        items := []
        if (texts.Length == 0)
            return items
        if (texts.Length != boxes.Length) {
            for t in texts
                items.Push({text: t, box: [], x: 0, y: 0, w: 0, h: 0, cx: 0, cy: 0})
            return items
        }
        Loop texts.Length {
            i := A_Index
            box := boxes[i]
            minX := box[1][1]
            maxX := box[1][1]
            minY := box[1][2]
            maxY := box[1][2]
            Loop box.Length {
                pt := box[A_Index]
                xv := pt[1]
                yv := pt[2]
                if (xv < minX)
                    minX := xv
                if (xv > maxX)
                    maxX := xv
                if (yv < minY)
                    minY := yv
                if (yv > maxY)
                    maxY := yv
            }
            items.Push({
                text: texts[i], box: box,
                x: minX, y: minY, w: maxX - minX, h: maxY - minY,
                cx: (minX + maxX) // 2, cy: (minY + maxY) // 2
            })
        }
        return items
    } catch {
        return []
    }
}

OCR_RegionDetailed(x, y, w, h) {
    tmpImg := A_Temp . "\OCR_" . A_TickCount . "_" . Random(1000, 9999) . ".bmp"
    CaptureAreaFile(x, y, w, h, tmpImg)
    items := DoOCR_File_Detailed(tmpImg)
    try FileDelete(tmpImg)
    Loop items.Length {
        item := items[A_Index]
        item.x += x
        item.y += y
        item.cx += x
        item.cy += y
        Loop item.box.Length {
            pt := item.box[A_Index]
            pt[1] += x
            pt[2] += y
        }
    }
    return items
}

FillValue(text) {
    if (RegExMatch(text, "^[\x20-\x7E]+$")) {
        SendText(text)
        return
    }
    clipboardOk := false
    try {
        A_Clipboard := text
        if (ClipWait(1))
            clipboardOk := true
        else {
            Sleep(100)
            A_Clipboard := text
            if (ClipWait(1))
                clipboardOk := true
        }
    } catch {
        Sleep(100)
        try {
            A_Clipboard := text
            if (ClipWait(1))
                clipboardOk := true
        }
    }
    if (!clipboardOk) {
        LogWrite("FillValue: 剪贴板写入失败，跳过填写")
        return
    }
    Send("^v")
}

_DecodeUnicode(text) {
    while RegExMatch(text, "\\u([0-9a-fA-F]{4})", &m) {
        text := StrReplace(text, "\u" . m[1], Chr(Integer("0x" . m[1])))
    }
    return text
}

FindRangeByKey(csvPath, ocrTxt) {
    global CSVCache
    cacheKey := csvPath . "|||" . ocrTxt
    if (CSVCache.Range.Has(cacheKey))
        return CSVCache.Range[cacheKey]
    ocr := Trim(ocrTxt)
    if (ocr == "" || !FileExist(csvPath))
        return {found: false, min: "", max: ""}
    csvLines := StrSplit(FileRead(csvPath, "UTF-8"), Chr(10), Chr(13))
    for line in csvLines {
        parts := StrSplit(line, ",")
        if (parts.Length >= 3 && Trim(parts[1]) == ocr)
            return {found: true, min: Trim(parts[2]), max: Trim(parts[3])}
    }
    bestLen := 0, bestMin := "", bestMax := ""
    for line in csvLines {
        parts := StrSplit(line, ",")
        if (parts.Length < 3)
            continue
        key := Trim(parts[1])
        if (key == "")
            continue
        if (InStr(ocr, key) || (ocr != "" && InStr(key, ocr))) {
            if (StrLen(key) > bestLen) {
                bestLen := StrLen(key)
                bestMin := Trim(parts[2]), bestMax := Trim(parts[3])
            }
        }
    }
    result := {found: bestLen > 0, min: bestMin, max: bestMax}
    CSVCache.Range[cacheKey] := result
    return result
}

CSVCacheClear() {
    global CSVCache
    CSVCache.KeyValues := Map()
    CSVCache.Coords := Map()
    CSVCache.Range := Map()
    CSVCache.MultiMap := Map()
}

; ================= 坐标/颜色/区域 捕获 =================
GetMousePos(*) {
    ToolTip("3秒后抓取...", 10, 10), Sleep(3000), ToolTip()
    MouseGetPos(&mx, &my)
    t := TypeDDL.Text
    if ((t == "🕹️ 条件跳过" && SkipBasisDDL.Text == "颜色") || (t == "🔀 条件分支开始 (If)" && IfTypeDDL.Text == "颜色匹配")) {
        InputSkipColorX.Value := mx, InputSkipColorY.Value := my
        InputSkipColor.Value := SubStr(PixelGetColor(mx, my, "RGB"), 3)
    } else {
        InputX.Value := mx, InputY.Value := my
    }
}

GetSkipColorPos(*) => GetMousePos()

GetFillPos(*) {
    ToolTip("3秒后抓取...", 10, 10), Sleep(3000), ToolTip()
    MouseGetPos(&mx, &my)
    InputFillX.Value := mx, InputFillY.Value := my
}
GetFillPos2(*) {
    ToolTip("3秒后抓取目标2...", 10, 10), Sleep(3000), ToolTip()
    MouseGetPos(&mx, &my)
    InputFillX2.Value := mx, InputFillY2.Value := my
}
GetFillPos3(*) {
    ToolTip("3秒后抓取目标3...", 10, 10), Sleep(3000), ToolTip()
    MouseGetPos(&mx, &my)
    InputFillX3.Value := mx, InputFillY3.Value := my
}

GetWinInfo(*) {
    ToolTip("请立即切换到目标窗口...", 10, 10), Sleep(3000)
    try {
        procName := WinGetProcessName(WinExist("A"))
        InputWinTitle.Value := "ahk_exe " procName
        ToolTip("已捕获: " InputWinTitle.Value, 10, 10)
        SetTimer(() => ToolTip(), -2000)
    } catch {
        ToolTip("❌ 获取窗口信息失败", 10, 10)
        SetTimer(() => ToolTip(), -2000)
    }
}

CaptureWindowTitle(targetCtrl) {
    ToolTip("请立即切换到目标窗口...", 10, 10), Sleep(3000), ToolTip()
    try {
        procName := WinGetProcessName(WinExist("A"))
        targetCtrl.Value := "ahk_exe " procName
        ToolTip("已捕获: " targetCtrl.Value, 10, 10)
        SetTimer(() => ToolTip(), -2000)
    } catch {
        ToolTip("❌ 获取窗口信息失败", 10, 10)
        SetTimer(() => ToolTip(), -2000)
    }
}

SelectImage(*) {
    path := FileSelect(3, , "选择要找的图片", "图像文件 (*.png; *.bmp; *.gif; *.jpg)")
    if (path)
        InputImg.Value := path
}

SelectApp(*) {
    path := FileSelect(3, A_Desktop, "选择要启动的程序 / 快捷方式",
        "程序与快捷方式 (*.exe; *.lnk; *.url; *.bat; *.cmd; *.com; *.msc)|所有文件 (*.*)")
    if (path) {
        InputAppPath.Value := path
        if (SubStr(StrLower(path), -3) == ".exe" && InputAppWin.Value == "") {
            SplitPath(path, &fn)
            InputAppWin.Value := "ahk_exe " fn
        }
    }
}

SelectSubScript(*) {
    path := FileSelect(3, A_ScriptDir, "选择子脚本", "AHK脚本或其他可执行文件 (*.ahk; *.exe; *.bat)")
    if (path != "") {
        InputSubScript.Value := path
        ToolTip("✅ 已选择子脚本：" path, 10, 10)
        SetTimer(() => ToolTip(), -2000)
    }
}

PastePathFromClipboard(*) {
    clip := Trim(A_Clipboard, " `"`n`r`t")
    if (clip == "")
        return MsgBox("剪贴板为空！请先去复制文件。", "提示", "Icon!")
    if (FileExist(clip)) {
        InputSubScript.Value := clip
        ToolTip("✅ 已粘贴路径：" clip, 10, 10)
        SetTimer(() => ToolTip(), -2000)
    } else {
        MsgBox("剪贴板中的路径不是有效的文件：`n" clip, "提示", "Iconx")
    }
}

WM_DROPFILES(wParam, lParam, msg, hwnd) {
    global InputSubScript, TypeDDL, InputImg
    DropFiles := DllCall("shell32\DragQueryFileW", "Ptr", wParam, "UInt", 0, "Ptr", 0, "UInt", 0)
    if (DropFiles > 0) {
        len := DllCall("shell32\DragQueryFileW", "Ptr", wParam, "UInt", 0, "Ptr", 0, "UInt", 0)
        buf := Buffer(len * 2 + 2, 0)
        DllCall("shell32\DragQueryFileW", "Ptr", wParam, "UInt", 0, "Ptr", buf, "UInt", len + 1)
        filePath := StrGet(buf, "UTF-16")
        
        if (RegExMatch(filePath, "i)\.(ahk|exe)$")) {
            if (InStr(TypeDDL.Text, "子脚本")) {
                InputSubScript.Value := filePath
                ToolTip("📦 已接收子脚本: " filePath, 10, 10)
                SetTimer(() => ToolTip(), -2000)
            }
        } else if (RegExMatch(filePath, "i)\.(png|bmp|jpg|gif)$")) {
            if (InStr(TypeDDL.Text, "截图找图")) {
                InputImg.Value := filePath
                ToolTip("🖼️ 已接收图片: " filePath, 10, 10)
                SetTimer(() => ToolTip(), -2000)
            }
        }
    }
    DllCall("shell32\DragFinish", "Ptr", wParam)
    return 0
}

SelectDB(*) {
    path := FileSelect(3, A_ScriptDir, "选择CSV数据库文件", "CSV文件 (*.csv)")
    if (path)
        InputDBPath.Value := path
}
SelectRandDB(*) {
    path := FileSelect(3, A_ScriptDir, "选择范围CSV文件", "CSV文件 (*.csv)")
    if (path)
        RandDBPath.Value := path
}
SelectRPosDB(*) {
    path := FileSelect(3, A_ScriptDir, "选择坐标表CSV文件", "CSV文件 (*.csv)")
    if (path)
        RPosDBPath.Value := path
}
SelectLogPath(*) {
    global LogPath
    path := FileSelect("S16", LogPath, "选择日志文件", "日志文件 (*.log; *.txt)")
    if (path)
        InputLogPath.Value := path, LogPath := path
}

GenerateDBTemplate(*) {
    tf := A_ScriptDir . "\DataMap_模板.csv"
    if (FileExist(tf)) {
        MsgBox("模板已存在：`n" tf)
        Run(tf)
        return
    }
    FileAppend("已领取,1`n未领取,0`n苹果,10.5`n香蕉,15", tf, "UTF-8")
    MsgBox("已生成模板：`n" tf)
    Run(tf)
}
GenerateRandDBTemplate(*) {
    tf := A_ScriptDir . "\DataMap_Range_模板.csv"
    if (FileExist(tf)) {
        MsgBox("模板已存在：`n" tf)
        Run(tf)
        return
    }
    FileAppend("苹果,10.5,15.2`n香蕉,15,20`n橙子,8,12.5", tf, "UTF-8")
    MsgBox("已生成（key,min,max）：`n" tf)
    Run(tf)
}
GenerateRPosDBTemplate(*) {
    tf := A_ScriptDir . "\Positions_模板.csv"
    if (FileExist(tf)) {
        MsgBox("模板已存在：`n" tf)
        Run(tf)
        return
    }
    FileAppend("X,Y`n478,50`n478,73`n478,96`n478,119", tf, "UTF-8")
    MsgBox("已生成坐标模板：`n" tf)
    Run(tf)
}
GenerateMultiDBTemplate(*) {
    tf := A_ScriptDir . "\MultiMap_模板.csv"
    if (FileExist(tf)) {
        MsgBox("模板已存在：`n" tf)
        Run(tf)
        return
    }
    FileAppend("类型A, 100, 200, 张总, 500, 200, 13800138000`n类型B, 150, 250, 李总, 550, 250, 13900139000", tf, "UTF-8")
    MsgBox("已生成多坐标模板：`n" tf)
    Run(tf)
}

StartCapture(*) {
    MyGui.Hide(), areaObj := SelectRegion(), MyGui.Show()
    if (areaObj)
        InputImg.Value := areaObj.path
}

SelectOcrArea(*) {
    global OCR_X, OCR_Y, OCR_W, OCR_H
    MyGui.Hide(), Sleep(200), areaObj := SelectRegion(), MyGui.Show()
    if (areaObj) {
        OCR_X := areaObj.x, OCR_Y := areaObj.y, OCR_W := areaObj.w, OCR_H := areaObj.h
        InputOcrArea.Value := "X:" OCR_X " Y:" OCR_Y " W:" OCR_W " H:" OCR_H
    }
}

SelectSkipOcrArea(*) {
    MyGui.Hide(), Sleep(200), areaObj := SelectRegion(), MyGui.Show()
    if (areaObj)
        InputSkipOcrArea.Value := "X:" areaObj.x " Y:" areaObj.y " W:" areaObj.w " H:" areaObj.h
}

SelectOcrSaveTxtArea(*) {
    MyGui.Hide(), Sleep(200), areaObj := SelectRegion(), MyGui.Show()
    if (areaObj)
        InputOcrSaveTxtArea.Value := "X:" . areaObj.x . " Y:" . areaObj.y . " W:" . areaObj.w . " H:" . areaObj.h
}
SelectOcrMatchTxtArea(*) {
    MyGui.Hide(), Sleep(200), areaObj := SelectRegion(), MyGui.Show()
    if (areaObj)
        InputOcrMatchTxtArea.Value := "X:" . areaObj.x . " Y:" . areaObj.y . " W:" . areaObj.w . " H:" . areaObj.h
}

; ================= 控件联动 =================
UpdateLoopSrcUI(*) {
    if (TypeDDL.Text != "🔁 局部循环开始")
        return
    if (LoopSrcDDL.Text == "固定值") {
        ParamInnerLoop.Visible := True, InputInnerLoop.Visible := True
        ParamLoopVarName.Visible := False, InputLoopVarName.Visible := False
    } else {
        ParamInnerLoop.Visible := False, InputInnerLoop.Visible := False
        ParamLoopVarName.Visible := True, InputLoopVarName.Visible := True
    }
}

UpdateExtractNumUI(*) {
    if (TypeDDL.Text != "识别并填写")
        return
    isNum := ChkExtractNum.Value
    ChkKeepDot.Visible := isNum
    ChkRound1.Visible := isNum
}

UpdateSaveToVarUI(*) {
    if (TypeDDL.Text != "识别并填写")
        return
    if (ChkSaveToVar.Value) {
        ChkOnlyClip.Visible := False
        ParamSaveVarName.Visible := True, InputSaveVarName.Visible := True
        ParamFillX.Visible := False, InputFillX.Visible := False
        ParamFillY.Visible := False, InputFillY.Visible := False, BtnGetFillPos.Visible := False
        ParamFillX2.Visible := False, InputFillX2.Visible := False
        ParamFillY2.Visible := False, InputFillY2.Visible := False, BtnGetFillPos2.Visible := False
        ParamFillX3.Visible := False, InputFillX3.Visible := False
        ParamFillY3.Visible := False, InputFillY3.Visible := False, BtnGetFillPos3.Visible := False
        ChkSendText.Visible := False
    } else {
        ChkOnlyClip.Visible := True
        ParamSaveVarName.Visible := False, InputSaveVarName.Visible := False
        ParamFillX.Visible := True, InputFillX.Visible := True
        ParamFillY.Visible := True, InputFillY.Visible := True, BtnGetFillPos.Visible := True
        ParamFillX2.Visible := True, InputFillX2.Visible := True
        ParamFillY2.Visible := True, InputFillY2.Visible := True, BtnGetFillPos2.Visible := True
        ParamFillX3.Visible := True, InputFillX3.Visible := True
        ParamFillY3.Visible := True, InputFillY3.Visible := True, BtnGetFillPos3.Visible := True
        ChkSendText.Visible := True
    }
}

UpdateSubWaitUI(*) {
    if (TypeDDL.Text != "📦 调用子脚本")
        return
    isWait := (SubWaitModeDDL.Text == "阻塞")
    ParamSubTimeout.Visible := isWait, InputSubTimeout.Visible := isWait, ParamSubTimeoutHint.Visible := isWait
}

ChangeSkipBasis(*) {
    if (TypeDDL.Text != "🕹️ 条件跳过")
        return
    isColor := (SkipBasisDDL.Text == "颜色")
    isOCR := (SkipBasisDDL.Text == "OCR文字")
    isVar := (SkipBasisDDL.Text == "变量匹配")

    ParamSkipColorX.Visible := isColor, InputSkipColorX.Visible := isColor
    ParamSkipColorY.Visible := isColor, InputSkipColorY.Visible := isColor
    BtnSkipColorGet.Visible := isColor, ParamSkipColor.Visible := isColor, InputSkipColor.Visible := isColor

    ParamSkipOcrArea.Visible := isOCR, InputSkipOcrArea.Visible := isOCR, BtnSkipSelectArea.Visible := isOCR
    ParamSkipKeyword.Visible := isOCR, InputSkipKeyword.Visible := isOCR

    ParamVarMatchName.Visible := isVar, InputVarMatchName.Visible := isVar, VarMatchHint.Visible := isVar
    ParamLoopCompareOp.Visible := isVar, LoopCompareOpDDL.Visible := isVar
    ParamLoopCompareVal.Visible := isVar, InputLoopCompareVal.Visible := isVar
}

ChangeIfType(*) {
    if (TypeDDL.Text != "🔀 条件分支开始 (If)")
        return
    isOCR := (IfTypeDDL.Text == "OCR包含文字")
    isColor := (IfTypeDDL.Text == "颜色匹配")
    isVar := (IfTypeDDL.Text == "变量匹配")

    ParamOcrArea.Visible := isOCR, InputOcrArea.Visible := isOCR, BtnSelectArea.Visible := isOCR
    ParamSkipKeyword.Visible := isOCR, InputSkipKeyword.Visible := isOCR

    ParamSkipColorX.Visible := isColor, InputSkipColorX.Visible := isColor
    ParamSkipColorY.Visible := isColor, InputSkipColorY.Visible := isColor
    BtnSkipColorGet.Visible := isColor
    ParamSkipColor.Visible := isColor, InputSkipColor.Visible := isColor

    ParamVarMatchName.Visible := isVar, InputVarMatchName.Visible := isVar, VarMatchHint.Visible := isVar
    ParamLoopCompareOp.Visible := isVar, LoopCompareOpDDL.Visible := isVar
    ParamLoopCompareVal.Visible := isVar, InputLoopCompareVal.Visible := isVar
}

ChangeFailPolicy(*) {
    global FailPolicy
    switch FailPolicyDDL.Value {
        case 1: FailPolicy := "stop"
        case 2: FailPolicy := "skip"
        case 3: FailPolicy := "retry1stop"
        case 4: FailPolicy := "retry3stop"
    }
}

UpdateLogUI(*) {
    global LogEnabled
    LogEnabled := ChkLogEnable.Value
    ParamLogPath.Visible := LogEnabled, InputLogPath.Visible := LogEnabled, BtnLogPath.Visible := LogEnabled
}

ChangeType(*) {
    t := TypeDDL.Text
    allCtrls := [
        ParamWinTitle, InputWinTitle, BtnGetWin, ParamWinWait, InputWinWait, ParamWinWaitHint,
        ParamAppPath, InputAppPath, BtnSelApp, ParamAppArgs, InputAppArgs, ParamAppWait, InputAppWait, ParamAppWin, InputAppWin, BtnAppGetWin,
        ParamX, InputX, ParamY, InputY, ParamOffsetX, InputOffsetX, ParamOffsetY, InputOffsetY, BtnGetPos,
        ParamClickCount, ClickCountDDL, ParamText, InputText, ChkPasteClip, ChkReplace,
        ParamKey, InputKey, BtnKeyTab, BtnKeyEnter, BtnKeyEsc,
        ParamMs, InputMs,
        ParamImg, InputImg, BtnSelectImg, BtnCapture, ParamImgAction, ImgActionDDL,
        ParamImgOffX, InputImgOffX, ParamImgOffY, InputImgOffY, ParamImgSim, InputImgSim,
        ParamImgWait, InputImgWait, ParamImgWaitHint,
        ParamOcrArea, InputOcrArea, BtnSelectArea, ChkExtractNum, ChkKeepDot, ChkRound1, ChkOnlyClip,
        ParamMath, InputMath, ParamMathHint, ChkUseDB, InputDBPath, BtnDBPath, BtnGenDB,
        ChkSendText, ChkSaveToVar, ParamSaveVarName, InputSaveVarName,
        ParamFillX, InputFillX, ParamFillY, InputFillY, BtnGetFillPos,
        ParamFillX2, InputFillX2, ParamFillY2, InputFillY2, BtnGetFillPos2,
        ParamFillX3, InputFillX3, ParamFillY3, InputFillY3, BtnGetFillPos3,
        ParamDecimal, DecimalDDL, ChkEven, ParamRDB, RandDBPath, RandBtnDB, RandBtnGen,
        ParamRPosDB, RPosDBPath, RPosBtnDB, RPosBtnGen, RandHint,
        ParamMultiDB, MultiDBPath, MultiBtnDB, MultiBtnGen, ParamMultiType, MultiTypeDDL, MultiHint,
        ParamSkipBasis, SkipBasisDDL, ParamSkipColorX, InputSkipColorX, ParamSkipColorY, InputSkipColorY,
        BtnSkipColorGet, ParamSkipColor, InputSkipColor, ParamSkipOcrArea, InputSkipOcrArea, BtnSkipSelectArea,
        ParamSkipKeyword, InputSkipKeyword, ParamSkipAction, SkipActionDDL, ParamSkip, InputSkip,
        ParamVarMatchName, InputVarMatchName, VarMatchHint, ParamLoopCompareOp, LoopCompareOpDDL, ParamLoopCompareVal, InputLoopCompareVal,
        ParamLoopSrc, LoopSrcDDL, ParamInnerLoop, InputInnerLoop, ParamLoopVarName, InputLoopVarName,
        ParamIfType, IfTypeDDL, ParamSetVarName, InputSetVarName, ParamSetVarValue, InputSetVarValue,
        ParamSubScript, InputSubScript, BtnSelSubScript, BtnPastePath, ParamSubArgs, InputSubArgs, ParamSubArgsHint,
        ParamSubWaitMode, SubWaitModeDDL, ParamSubTimeout, InputSubTimeout, ParamSubTimeoutHint,
        ParamSubResultVar, InputSubResultVar, ParamSubResultVarHint,
        ParamSubResultFile, InputSubResultFile, ParamSubResultFileHint,
        ParamOcrSaveTxtArea, InputOcrSaveTxtArea, BtnOcrSaveTxtSelectArea,
        ParamExtractMode, ExtractModeDDL, ParamExtractN, InputExtractN,
        ParamFilterRe, InputFilterRe, ParamDelimiter, DelimiterDDL,
        ParamSaveTxtVar, InputSaveTxtVar,
        ParamOcrMatchTxtArea, InputOcrMatchTxtArea, BtnOcrMatchTxtSelectArea,
        ParamMatchTxtKeyword, InputMatchTxtKeyword, ParamMatchTxtHint,
        ParamMatchTxtMode, MatchTxtModeDDL, ParamMatchTxtStrategy, MatchTxtStrategyDDL,
        ParamMatchTxtN, InputMatchTxtN,
        ParamMatchTxtPos, MatchTxtPosDDL, ParamMatchTxtOffX, InputMatchTxtOffX,
        ParamMatchTxtOffY, InputMatchTxtOffY, ParamMatchTxtAction, MatchTxtActionDDL,
        ParamMatchTxtWait, InputMatchTxtWait, ParamMatchTxtWaitHint
    ]
    for c in allCtrls
        c.Visible := False
    
    if (t == "激活窗口") {
        ParamWinTitle.Visible := True, InputWinTitle.Visible := True, BtnGetWin.Visible := True
        ParamWinWait.Visible := True, InputWinWait.Visible := True, ParamWinWaitHint.Visible := True
    } else if (t == "🚀 启动应用/快捷方式") {
        ParamAppPath.Visible := True, InputAppPath.Visible := True, BtnSelApp.Visible := True
        ParamAppArgs.Visible := True, InputAppArgs.Visible := True
        ParamAppWait.Visible := True, InputAppWait.Visible := True
        ParamAppWin.Visible := True, InputAppWin.Visible := True, BtnAppGetWin.Visible := True
    } else if (t == "点击坐标") {
        ParamX.Visible := True, InputX.Visible := True, ParamY.Visible := True, InputY.Visible := True
        ParamOffsetX.Visible := True, InputOffsetX.Visible := True, ParamOffsetY.Visible := True, InputOffsetY.Visible := True
        BtnGetPos.Visible := True
        ParamClickCount.Visible := True, ClickCountDDL.Visible := True
        ParamText.Visible := True, InputText.Visible := True, ChkPasteClip.Visible := True, ChkReplace.Visible := True
    } else if (t == "发送按键") {
        ParamKey.Visible := True, InputKey.Visible := True
        BtnKeyTab.Visible := True, BtnKeyEnter.Visible := True, BtnKeyEsc.Visible := True
    } else if (t == "延时等待") {
        ParamMs.Visible := True, InputMs.Visible := True
    } else if (t == "截图找图") {
        ParamImg.Visible := True, InputImg.Visible := True, BtnSelectImg.Visible := True, BtnCapture.Visible := True
        ParamImgAction.Visible := True, ImgActionDDL.Visible := True
        ParamImgOffX.Visible := True, InputImgOffX.Visible := True
        ParamImgOffY.Visible := True, InputImgOffY.Visible := True
        ParamImgSim.Visible := True, InputImgSim.Visible := True
        ParamImgWait.Visible := True, InputImgWait.Visible := True, ParamImgWaitHint.Visible := True
    } else if (t == "识别并填写") {
        ParamOcrArea.Visible := True, InputOcrArea.Visible := True, BtnSelectArea.Visible := True
        ChkExtractNum.Visible := True
        ChkKeepDot.Visible := ChkExtractNum.Value
        ChkRound1.Visible := ChkExtractNum.Value
        ParamMath.Visible := True, InputMath.Visible := True, ParamMathHint.Visible := True
        ChkUseDB.Visible := True, InputDBPath.Visible := True, BtnDBPath.Visible := True, BtnGenDB.Visible := True
        ChkSaveToVar.Visible := True
        if (ChkSaveToVar.Value) {
            ChkOnlyClip.Visible := False
            ParamSaveVarName.Visible := True, InputSaveVarName.Visible := True
            ChkSendText.Visible := False
        } else {
            ChkOnlyClip.Visible := True
            ParamFillX.Visible := True, InputFillX.Visible := True
            ParamFillY.Visible := True, InputFillY.Visible := True, BtnGetFillPos.Visible := True
            ParamFillX2.Visible := True, InputFillX2.Visible := True
            ParamFillY2.Visible := True, InputFillY2.Visible := True, BtnGetFillPos2.Visible := True
            ParamFillX3.Visible := True, InputFillX3.Visible := True
            ParamFillY3.Visible := True, InputFillY3.Visible := True, BtnGetFillPos3.Visible := True
            ChkSendText.Visible := True
        }
        UpdateSaveToVarUI()
    } else if (t == "🎲 范围随机填写") {
        ParamOcrArea.Visible := True, InputOcrArea.Visible := True, BtnSelectArea.Visible := True
        ParamDecimal.Visible := True, DecimalDDL.Visible := True, ChkEven.Visible := True
        ParamRDB.Visible := True, RandDBPath.Visible := True, RandBtnDB.Visible := True, RandBtnGen.Visible := True
        ParamRPosDB.Visible := True, RPosDBPath.Visible := True, RPosBtnDB.Visible := True, RPosBtnGen.Visible := True
        RandHint.Visible := True
    } else if (t == "📊 坐标查表填写") {
        ParamMultiDB.Visible := True, MultiDBPath.Visible := True, MultiBtnDB.Visible := True, MultiBtnGen.Visible := True
        ParamMultiType.Visible := True, MultiTypeDDL.Visible := True, MultiHint.Visible := True
    } else if (t == "🕹️ 条件跳过") {
        ParamSkipBasis.Visible := True, SkipBasisDDL.Visible := True
        ParamSkipAction.Visible := True, SkipActionDDL.Visible := True, ParamSkip.Visible := True, InputSkip.Visible := True
        ChangeSkipBasis()
    } else if (t == "🔁 局部循环开始") {
        ParamLoopSrc.Visible := True, LoopSrcDDL.Visible := True
        UpdateLoopSrcUI()
    } else if (t == "🔀 条件分支开始 (If)") {
        ParamIfType.Visible := True, IfTypeDDL.Visible := True
        ChangeIfType()
    } else if (t == "📝 设置变量") {
        ParamSetVarName.Visible := True, InputSetVarName.Visible := True
        ParamSetVarValue.Visible := True, InputSetVarValue.Visible := True
    } else if (t == "🔍 OCR识别保存文本") {
        ParamOcrSaveTxtArea.Visible := True, InputOcrSaveTxtArea.Visible := True, BtnOcrSaveTxtSelectArea.Visible := True
        ParamExtractMode.Visible := True, ExtractModeDDL.Visible := True
        ParamExtractN.Visible := True, InputExtractN.Visible := True
        ParamFilterRe.Visible := True, InputFilterRe.Visible := True
        ParamDelimiter.Visible := True, DelimiterDDL.Visible := True
        ParamSaveTxtVar.Visible := True, InputSaveTxtVar.Visible := True
    } else if (t == "🎯 匹配文本并点击") {
        ParamOcrMatchTxtArea.Visible := True, InputOcrMatchTxtArea.Visible := True, BtnOcrMatchTxtSelectArea.Visible := True
        ParamMatchTxtKeyword.Visible := True, InputMatchTxtKeyword.Visible := True, ParamMatchTxtHint.Visible := True
        ParamMatchTxtMode.Visible := True, MatchTxtModeDDL.Visible := True
        ParamMatchTxtStrategy.Visible := True, MatchTxtStrategyDDL.Visible := True
        ParamMatchTxtN.Visible := True, InputMatchTxtN.Visible := True
        ParamMatchTxtPos.Visible := True, MatchTxtPosDDL.Visible := True
        ParamMatchTxtOffX.Visible := True, InputMatchTxtOffX.Visible := True
        ParamMatchTxtOffY.Visible := True, InputMatchTxtOffY.Visible := True
        ParamMatchTxtAction.Visible := True, MatchTxtActionDDL.Visible := True
        ParamMatchTxtWait.Visible := True, InputMatchTxtWait.Visible := True, ParamMatchTxtWaitHint.Visible := True
    } else if (t == "📦 调用子脚本") {
        ParamSubScript.Visible := True, InputSubScript.Visible := True, BtnSelSubScript.Visible := True, BtnPastePath.Visible := True
        ParamSubArgs.Visible := True, InputSubArgs.Visible := True, ParamSubArgsHint.Visible := True
        ParamSubWaitMode.Visible := True, SubWaitModeDDL.Visible := True
        ParamSubResultVar.Visible := True, InputSubResultVar.Visible := True, ParamSubResultVarHint.Visible := True
        ParamSubResultFile.Visible := True, InputSubResultFile.Visible := True, ParamSubResultFileHint.Visible := True
        UpdateSubWaitUI()
    }
}

OnTaskDoubleClick(*) {
    global TaskArr
    Row := LV.GetNext()
    if (!Row || Row > TaskArr.Length)
        return
    obj := TaskArr[Row]
    if (obj.type == "截图找图") {
        curPath := obj.HasOwnProp("path") ? obj.path : ""
        path := FileSelect(3, curPath, "重新选择要找的图片", "图像文件 (*.png; *.bmp; *.gif; *.jpg)")
        if (path) {
            obj.path := path, RebuildLV(), LV.Modify(Row, "Select Vis")
            StatusBar.SetText("✅ 已更新第 " Row " 步的图片: " path)
        }
    }
}

BtnRunHandler(*) {
    global DebugStartIP
    DebugStartIP := 1
    RunTasks()
}

BtnRunFromHandler(*) {
    global DebugStartIP
    Row := LV.GetNext()
    if (!Row)
        return MsgBox("请先在任务列表中选中要从哪一步开始！", "提示", "Icon!")
    DebugStartIP := Row
    RunTasks()
}

BtnEditHandler(*) {
    global EditingIndex
    if (EditingIndex > 0)
        AddTask(False)
    else
        EditTask()
}

CancelEdit(*) {
    global EditingIndex
    EditingIndex := 0
    BtnEdit.Text := "✏ 编辑选中"
    BtnCancelEdit.Visible := False
    InputRemark.Value := ""
    StatusBar.SetText("❌ 已取消编辑")
}

; ================= EditTask =================
EditTask(*) {
    global TaskArr, EditingIndex, TypeList
    Row := LV.GetNext()
    if (!Row || Row > TaskArr.Length)
        return MsgBox("请先在下方任务列表中选中要编辑的任务！", "提示", "Icon!")
    obj := TaskArr[Row]
    
    typeName := obj.type
    if (typeName == "识别数字并填写")
        typeName := "识别并填写"
    
    tIdx := 1
    for i, tt in TypeList {
        if (tt == typeName) {
            tIdx := i
            break
        }
    }
    TypeDDL.Value := tIdx
    ChangeType()
    
    InputWinTitle.Value := "ahk_exe chrome.exe", InputWinWait.Value := "0"
    InputAppPath.Value := "", InputAppArgs.Value := "", InputAppWait.Value := "1500", InputAppWin.Value := ""
    InputX.Value := "", InputY.Value := "", InputOffsetX.Value := "0", InputOffsetY.Value := "0"
    ClickCountDDL.Text := "1", InputText.Value := "", ChkReplace.Value := true, ChkPasteClip.Value := false
    InputKey.Value := "{Tab}"
    InputMs.Value := "500"
    InputImg.Value := "", InputImgSim.Value := "70", ImgActionDDL.Value := 1
    InputImgOffX.Value := "0", InputImgOffY.Value := "0", InputImgWait.Value := "0"
    InputOcrArea.Value := "未选择区域"
    ChkExtractNum.Value := true
    ChkKeepDot.Value := true, ChkRound1.Value := false, ChkOnlyClip.Value := false
    InputMath.Value := "", ChkUseDB.Value := false, InputDBPath.Value := "DataMap.csv"
    ChkSendText.Value := true, ChkSaveToVar.Value := false, InputSaveVarName.Value := "LoopCount_OCR"
    InputFillX.Value := "", InputFillY.Value := "", InputFillX2.Value := "", InputFillY2.Value := ""
    InputFillX3.Value := "", InputFillY3.Value := ""
    DecimalDDL.Value := 1, ChkEven.Value := false
    RandDBPath.Value := "DataMap_Range.csv", RPosDBPath.Value := "Positions.csv"
    MultiDBPath.Value := "MultiMap.csv", MultiTypeDDL.Value := 1
    SkipBasisDDL.Value := 1, InputSkipColorX.Value := "", InputSkipColorY.Value := "", InputSkipColor.Value := "FF0000"
    InputSkipOcrArea.Value := "未选择区域", InputSkipKeyword.Value := ""
    SkipActionDDL.Value := 1, InputSkip.Value := "1"
    InputVarMatchName.Value := "CurrentLoop", LoopCompareOpDDL.Value := 1, InputLoopCompareVal.Value := "1"
    LoopSrcDDL.Value := 1, InputInnerLoop.Value := "3", InputLoopVarName.Value := "LoopCount_OCR"
    IfTypeDDL.Value := 1
    InputSetVarName.Value := "MyVar", InputSetVarValue.Value := ""
    InputSubScript.Value := "", InputSubArgs.Value := "", SubWaitModeDDL.Value := 1
    InputSubTimeout.Value := "0", InputSubResultVar.Value := "", InputSubResultFile.Value := ""
    InputRemark.Value := obj.HasOwnProp("remark") ? obj.remark : ""
    
    switch typeName {
        case "激活窗口":
            InputWinTitle.Value := obj.winTitle
            InputWinWait.Value := obj.HasOwnProp("winWait") ? obj.winWait : "0"
        case "🚀 启动应用/快捷方式":
            InputAppPath.Value := obj.path, InputAppArgs.Value := obj.args
            InputAppWait.Value := obj.waitMs, InputAppWin.Value := obj.winTitle
        case "点击坐标":
            InputX.Value := obj.x, InputY.Value := obj.y
            InputOffsetX.Value := obj.offsetX, InputOffsetY.Value := obj.offsetY
            ClickCountDDL.Text := obj.HasOwnProp("clickCount") ? String(obj.clickCount) : "1"
            InputText.Value := obj.HasOwnProp("text") ? obj.text : ""
            ChkReplace.Value := obj.HasOwnProp("replace") ? obj.replace : true
            ChkPasteClip.Value := obj.HasOwnProp("pasteClip") ? obj.pasteClip : false
        case "发送按键":
            InputKey.Value := obj.key
        case "延时等待":
            InputMs.Value := obj.ms
        case "截图找图":
            InputImg.Value := obj.path
            InputImgSim.Value := obj.HasOwnProp("sim") ? obj.sim : "70"
            act := obj.HasOwnProp("imgAction") ? obj.imgAction : "点击图片中心"
            if (act == "点击图片中心")
                ImgActionDDL.Value := 1
            else if (act == "点击图片左上角")
                ImgActionDDL.Value := 2
            else
                ImgActionDDL.Value := 3
            InputImgOffX.Value := obj.HasOwnProp("imgOffX") ? obj.imgOffX : 0
            InputImgOffY.Value := obj.HasOwnProp("imgOffY") ? obj.imgOffY : 0
            InputImgWait.Value := obj.HasOwnProp("imgWait") ? obj.imgWait : 0
        case "识别并填写":
            ChkExtractNum.Value := obj.HasOwnProp("extractNum") ? obj.extractNum : true
            InputOcrArea.Value := "X:" obj.ocrX " Y:" obj.ocrY " W:" obj.ocrW " H:" obj.ocrH
            ChkKeepDot.Value := obj.keepDot, ChkRound1.Value := obj.round1, ChkOnlyClip.Value := obj.onlyClip
            InputMath.Value := obj.mathOp, ChkUseDB.Value := obj.useDB, InputDBPath.Value := obj.dbPath
            ChkSendText.Value := obj.HasOwnProp("sendText") ? obj.sendText : true
            ChkSaveToVar.Value := obj.HasOwnProp("saveToVar") ? obj.saveToVar : false
            InputSaveVarName.Value := obj.HasOwnProp("saveVarName") ? obj.saveVarName : "LoopCount_OCR"
            UpdateExtractNumUI()
            UpdateSaveToVarUI()
            InputFillX.Value := obj.fillX, InputFillY.Value := obj.fillY
            if (obj.HasOwnProp("fillX2"))
                InputFillX2.Value := obj.fillX2
            if (obj.HasOwnProp("fillY2"))
                InputFillY2.Value := obj.fillY2
            if (obj.HasOwnProp("fillX3"))
                InputFillX3.Value := obj.fillX3
            if (obj.HasOwnProp("fillY3"))
                InputFillY3.Value := obj.fillY3
        case "🎲 范围随机填写":
            InputOcrArea.Value := "X:" obj.ocrX " Y:" obj.ocrY " W:" obj.ocrW " H:" obj.ocrH
            DecimalDDL.Value := (obj.decimals + 1)
            ChkEven.Value := obj.HasOwnProp("onlyEven") ? obj.onlyEven : false
            RandDBPath.Value := obj.dbPath, RPosDBPath.Value := obj.posDBPath
        case "📊 坐标查表填写":
            MultiDBPath.Value := obj.dbPath
            MultiTypeDDL.Value := (obj.HasOwnProp("matchType") && obj.matchType == "用包含文字匹配") ? 2 : 1
        case "🕹️ 条件跳过":
            skipBasis := obj.HasOwnProp("skipBasis") ? obj.skipBasis : "颜色"
            if (skipBasis == "颜色") {
                SkipBasisDDL.Value := 1
                InputSkipColorX.Value := obj.x, InputSkipColorY.Value := obj.y, InputSkipColor.Value := obj.color
            } else if (skipBasis == "变量匹配") {
                SkipBasisDDL.Value := 3
                InputVarMatchName.Value := obj.HasOwnProp("matchVar") ? obj.matchVar : "CurrentLoop"
                opVal := obj.HasOwnProp("loopOp") ? obj.loopOp : "=="
                LoopCompareOpDDL.Value := (opVal == "==" ? 1 : opVal == "!=" ? 2 : opVal == ">" ? 3 : opVal == "<" ? 4 : opVal == ">=" ? 5 : opVal == "<=" ? 6 : opVal == "包含" ? 7 : 8)
                InputLoopCompareVal.Value := obj.HasOwnProp("loopTarget") ? obj.loopTarget : "1"
            } else {
                SkipBasisDDL.Value := 2
                InputSkipOcrArea.Value := "X:" obj.ocrX " Y:" obj.ocrY " W:" obj.ocrW " H:" obj.ocrH
                InputSkipKeyword.Value := obj.keyword
            }
            ChangeSkipBasis()
            act := obj.HasOwnProp("skipAction") ? obj.skipAction : "匹配 → 跳过N步"
            if (act == "匹配 → 跳过N步")
                SkipActionDDL.Value := 1
            else if (act == "不匹配 → 跳过N步")
                SkipActionDDL.Value := 2
            else
                SkipActionDDL.Value := 3
            InputSkip.Value := obj.HasOwnProp("skipN") ? obj.skipN : 1
        case "🔁 局部循环开始":
            src := obj.HasOwnProp("loopSrc") ? obj.loopSrc : "固定值"
            if (src == "固定值")
                LoopSrcDDL.Value := 1
            else
                LoopSrcDDL.Value := 2
            UpdateLoopSrcUI()
            InputInnerLoop.Value := obj.HasOwnProp("count") ? obj.count : 3
            InputLoopVarName.Value := obj.HasOwnProp("varName") ? obj.varName : "LoopCount_OCR"
        case "🔀 条件分支开始 (If)":
            if (obj.ifType == "OCR包含文字") {
                IfTypeDDL.Value := 1
                InputOcrArea.Value := "X:" obj.ocrX " Y:" obj.ocrY " W:" obj.ocrW " H:" obj.ocrH
                InputSkipKeyword.Value := obj.keyword
            } else if (obj.ifType == "变量匹配") {
                IfTypeDDL.Value := 3
                InputVarMatchName.Value := obj.HasOwnProp("matchVar") ? obj.matchVar : "CurrentLoop"
                opVal := obj.HasOwnProp("loopOp") ? obj.loopOp : "=="
                LoopCompareOpDDL.Value := (opVal == "==" ? 1 : opVal == "!=" ? 2 : opVal == ">" ? 3 : opVal == "<" ? 4 : opVal == ">=" ? 5 : opVal == "<=" ? 6 : opVal == "包含" ? 7 : 8)
                InputLoopCompareVal.Value := obj.HasOwnProp("loopTarget") ? obj.loopTarget : "1"
            } else {
                IfTypeDDL.Value := 2
                InputSkipColorX.Value := obj.x, InputSkipColorY.Value := obj.y, InputSkipColor.Value := obj.color
            }
            ChangeIfType()
        case "📝 设置变量":
            InputSetVarName.Value := obj.varName
            InputSetVarValue.Value := obj.varValue
        case "🔍 OCR识别保存文本":
            InputOcrSaveTxtArea.Value := "X:" . obj.ocrX . " Y:" . obj.ocrY . " W:" . obj.ocrW . " H:" . obj.ocrH
            em := obj.HasOwnProp("extractMode") ? obj.extractMode : "全部文本"
            ExtractModeDDL.Value := (em == "第N项" ? 2 : em == "首个匹配正则" ? 3 : em == "全部匹配正则" ? 4 : 1)
            InputExtractN.Value := obj.HasOwnProp("extractN") ? obj.extractN : 1
            InputFilterRe.Value := obj.HasOwnProp("filterRegex") ? obj.filterRegex : ""
            dl := obj.HasOwnProp("delimiter") ? obj.delimiter : "换行"
            DelimiterDDL.Value := (dl == "逗号" ? 2 : dl == "空格" ? 3 : dl == "制表符" ? 4 : 1)
            InputSaveTxtVar.Value := obj.HasOwnProp("saveVar") ? obj.saveVar : "OCRText"
        case "🎯 匹配文本并点击":
            InputOcrMatchTxtArea.Value := "X:" . obj.ocrX . " Y:" . obj.ocrY . " W:" . obj.ocrW . " H:" . obj.ocrH
            InputMatchTxtKeyword.Value := obj.HasOwnProp("keyword") ? obj.keyword : ""
            mtm := obj.HasOwnProp("matchMode") ? obj.matchMode : "包含"
            MatchTxtModeDDL.Value := (mtm == "完全等于" ? 2 : mtm == "正则" ? 3 : 1)
            mts := obj.HasOwnProp("matchStrategy") ? obj.matchStrategy : "第一个"
            MatchTxtStrategyDDL.Value := (mts == "全部" ? 2 : mts == "第N个" ? 3 : 1)
            InputMatchTxtN.Value := obj.HasOwnProp("matchN") ? obj.matchN : 1
            mtp := obj.HasOwnProp("clickPos") ? obj.clickPos : "文字中心"
            MatchTxtPosDDL.Value := (mtp == "左上角" ? 2 : mtp == "右下角" ? 3 : mtp == "右侧中点" ? 4 : 1)
            InputMatchTxtOffX.Value := obj.HasOwnProp("clickOffX") ? obj.clickOffX : 0
            InputMatchTxtOffY.Value := obj.HasOwnProp("clickOffY") ? obj.clickOffY : 0
            mta := obj.HasOwnProp("clickAction") ? obj.clickAction : "点击"
            MatchTxtActionDDL.Value := (mta == "仅移动不点击" ? 2 : 1)
            InputMatchTxtWait.Value := obj.HasOwnProp("findWait") ? obj.findWait : 0
        case "📦 调用子脚本":
            InputSubScript.Value := obj.HasOwnProp("scriptPath") ? obj.scriptPath : ""
            InputSubArgs.Value := obj.HasOwnProp("args") ? obj.args : ""
            SubWaitModeDDL.Value := (obj.HasOwnProp("waitMode") && obj.waitMode == "不等待") ? 2 : 1
            UpdateSubWaitUI()
            InputSubTimeout.Value := obj.HasOwnProp("timeout") ? obj.timeout : "0"
            InputSubResultVar.Value := obj.HasOwnProp("resultVarName") ? obj.resultVarName : ""
            InputSubResultFile.Value := obj.HasOwnProp("resultFile") ? obj.resultFile : ""
    }
    
    EditingIndex := Row
    BtnEdit.Text := "💾 保存修改"
    BtnCancelEdit.Visible := True
    StatusBar.SetText("✏ 正在编辑第 " Row " 行")
}

; ================= AddTask =================
AddTask(IsInsert := False) {
    global TaskArr, OCR_X, OCR_Y, OCR_W, OCR_H, EditingIndex
    t := TypeDDL.Text
    Params := "", Obj := {type: t, remark: InputRemark.Value}
    
    if (t == "激活窗口") {
        if (InputWinTitle.Value == "")
            return MsgBox("请输入窗口标题！", "提示", "Icon!")
        Obj.winTitle := InputWinTitle.Value
        Obj.winWait := Integer(InputWinWait.Value == "" ? 0 : InputWinWait.Value)
        Params := "激活: " Obj.winTitle " (等" Obj.winWait "s)"
    } else if (t == "🚀 启动应用/快捷方式") {
        if (InputAppPath.Value == "")
            return MsgBox("请选择要启动的应用或快捷方式！", "提示", "Icon!")
        Obj.path := InputAppPath.Value, Obj.args := InputAppArgs.Value
        Obj.waitMs := Integer(InputAppWait.Value == "" ? 1500 : InputAppWait.Value)
        Obj.winTitle := InputAppWin.Value
        Params := "启动: " Obj.path
        if (Obj.args != "")
            Params .= " [" Obj.args "]"
        if (Obj.winTitle != "")
            Params .= " → " Obj.winTitle
    } else if (t == "点击坐标") {
        if (InputX.Value == "" || InputY.Value == "")
            return MsgBox("请输入或获取坐标！", "提示", "Icon!")
        cntStr := Trim(ClickCountDDL.Text)
        if (!RegExMatch(cntStr, "^\d+$") || Integer(cntStr) < 1)
            return MsgBox("点击次数必须是正整数！", "提示", "Icon!")
        Obj.x := Integer(InputX.Value), Obj.y := Integer(InputY.Value)
        Obj.offsetX := Integer(InputOffsetX.Value == "" ? 0 : InputOffsetX.Value)
        Obj.offsetY := Integer(InputOffsetY.Value == "" ? 0 : InputOffsetY.Value)
        Obj.clickCount := Integer(cntStr)
        Obj.text := InputText.Value
        Obj.replace := ChkReplace.Value, Obj.pasteClip := ChkPasteClip.Value
        Params := "X:" Obj.x ", Y:" Obj.y " x" Obj.clickCount
        if (Obj.offsetX != 0 || Obj.offsetY != 0)
            Params .= " (偏移:" Obj.offsetX "," Obj.offsetY ")"
        if (Obj.text != "" || Obj.pasteClip)
            Params .= " → " (Obj.pasteClip ? "[粘贴]" : Obj.text)
    } else if (t == "发送按键") {
        if (InputKey.Value == "")
            return MsgBox("请输入按键！", "提示", "Icon!")
        Obj.key := InputKey.Value, Params := "按键: " Obj.key
    } else if (t == "延时等待") {
        Obj.ms := InputMs.Value, Params := "等待 " Obj.ms " 毫秒"
    } else if (t == "截图找图") {
        if (InputImg.Value == "")
            return MsgBox("请选择图片！", "提示", "Icon!")
        Obj.path := InputImg.Value
        Obj.sim := Integer(InputImgSim.Value == "" ? 70 : InputImgSim.Value)
        Obj.imgAction := ImgActionDDL.Text
        Obj.imgOffX := Integer(InputImgOffX.Value == "" ? 0 : InputImgOffX.Value)
        Obj.imgOffY := Integer(InputImgOffY.Value == "" ? 0 : InputImgOffY.Value)
        Obj.imgWait := Integer(InputImgWait.Value == "" ? 0 : InputImgWait.Value)
        Params := "图片: " Obj.path " | " Obj.imgAction
        if (Obj.imgWait > 0)
            Params .= " (等" Obj.imgWait "s)"
    } else if (t == "识别并填写") {
        Obj.extractNum := ChkExtractNum.Value
        Obj.saveToVar := ChkSaveToVar.Value
        Obj.sendText := ChkSendText.Value
        if (InputOcrArea.Value == "未选择区域")
            return MsgBox("请框选识别区域！", "提示", "Icon!")
        Obj.ocrX := OCR_X, Obj.ocrY := OCR_Y, Obj.ocrW := OCR_W, Obj.ocrH := OCR_H
        Obj.keepDot := ChkKeepDot.Value, Obj.round1 := ChkRound1.Value
        Obj.mathOp := InputMath.Value, Obj.useDB := ChkUseDB.Value, Obj.dbPath := InputDBPath.Value
        if (Obj.useDB && !RegExMatch(Obj.dbPath, "^[A-Za-z]:"))
            Obj.dbPath := A_ScriptDir . "\" . Obj.dbPath
        if (Obj.useDB && Obj.dbPath != "" && !FileExist(Obj.dbPath))
            return MsgBox("CSV 不存在：`n" Obj.dbPath, "提示", "Icon!")
        if (Obj.saveToVar) {
            Obj.onlyClip := false
            Obj.saveVarName := InputSaveVarName.Value == "" ? "LoopCount_OCR" : InputSaveVarName.Value
            Obj.fillX := 0, Obj.fillY := 0, Obj.fillX2 := 0, Obj.fillY2 := 0, Obj.fillX3 := 0, Obj.fillY3 := 0
            Params := "存 " Obj.saveVarName
        } else {
            Obj.onlyClip := ChkOnlyClip.Value
            if (!Obj.onlyClip && InputFillX.Value == "")
                return MsgBox("请设置填入坐标！", "提示", "Icon!")
            Obj.fillX := Obj.onlyClip ? 0 : Integer(InputFillX.Value)
            Obj.fillY := Obj.onlyClip ? 0 : Integer(InputFillY.Value)
            Obj.fillX2 := Obj.onlyClip ? 0 : (InputFillX2.Value == "" ? 0 : Integer(InputFillX2.Value))
            Obj.fillY2 := Obj.onlyClip ? 0 : (InputFillY2.Value == "" ? 0 : Integer(InputFillY2.Value))
            Obj.fillX3 := Obj.onlyClip ? 0 : (InputFillX3.Value == "" ? 0 : Integer(InputFillX3.Value))
            Obj.fillY3 := Obj.onlyClip ? 0 : (InputFillY3.Value == "" ? 0 : Integer(InputFillY3.Value))
            tgtCnt := 1
            if (Obj.fillX2 != 0 || Obj.fillY2 != 0)
                tgtCnt := 2
            if (Obj.fillX3 != 0 || Obj.fillY3 != 0)
                tgtCnt := 3
            Params := Obj.onlyClip ? "仅剪贴板" : ("填入 " tgtCnt " 处")
            Params .= Obj.extractNum ? " [数字]" : " [原文]"
            if (Obj.sendText)
                Params .= " [SendText]"
        }
    } else if (t == "🎲 范围随机填写") {
        if (InputOcrArea.Value == "未选择区域")
            return MsgBox("请框选识别区域！", "提示", "Icon!")
        dbPath := RandDBPath.Value
        if (!RegExMatch(dbPath, "^[A-Za-z]:"))
            dbPath := A_ScriptDir . "\" . dbPath
        if (!FileExist(dbPath))
            return MsgBox("范围 CSV 不存在：" . dbPath, "提示", "Icon!")
        posDB := RPosDBPath.Value
        if (!RegExMatch(posDB, "^[A-Za-z]:"))
            posDB := A_ScriptDir . "\" . posDB
        if (!FileExist(posDB))
            return MsgBox("坐标 CSV 不存在：" . posDB, "提示", "Icon!")
        coordList := LoadCoordsCSV(posDB)
        if (coordList.Length == 0)
            return MsgBox("坐标 CSV 无有效行：" . posDB, "提示", "Icon!")
        Obj.ocrX := OCR_X, Obj.ocrY := OCR_Y, Obj.ocrW := OCR_W, Obj.ocrH := OCR_H
        Obj.dbPath := dbPath, Obj.posDBPath := posDB
        Obj.decimals := DecimalDDL.Value - 1
        Obj.onlyEven := ChkEven.Value
        Params := "坐标表 " coordList.Length " 组 | " (Obj.decimals == 0 ? "整数" : Obj.decimals "位小数")
    } else if (t == "📊 坐标查表填写") {
        dbP := MultiDBPath.Value
        if (dbP == "")
            return MsgBox("请选择数据 CSV！", "提示", "Icon!")
        if (!RegExMatch(dbP, "^[A-Za-z]:"))
            dbP := A_ScriptDir . "\" . dbP
        if (!FileExist(dbP))
            return MsgBox("数据 CSV 不存在：" . dbP, "提示", "Icon!")
        Obj.dbPath := dbP, Obj.matchType := MultiTypeDDL.Text
        Params := "数据查表: " Obj.dbPath " (" Obj.matchType ")"
    } else if (t == "🕹️ 条件跳过") {
        skipBasis := SkipBasisDDL.Text
        Obj.skipBasis := skipBasis
        if (skipBasis == "颜色") {
            if (InputSkipColorX.Value == "" || InputSkipColor.Value == "")
                return MsgBox("请设置坐标和颜色！", "提示", "Icon!")
            Obj.x := Integer(InputSkipColorX.Value), Obj.y := Integer(InputSkipColorY.Value)
            cVal := RegExReplace(InputSkipColor.Value, "(?i)^(0x|#)", "")
            if (!RegExMatch(StrUpper(Trim(cVal)), "^[0-9A-F]{6}$"))
                return MsgBox("颜色值格式错误！", "提示", "Icon!")
            Obj.color := StrUpper(Trim(cVal))
            Params := "颜色 (" Obj.x "," Obj.y ")=" Obj.color
        } else if (skipBasis == "变量匹配") {
            Obj.matchVar := InputVarMatchName.Value == "" ? "CurrentLoop" : InputVarMatchName.Value
            Obj.loopOp := LoopCompareOpDDL.Text
            Obj.loopTarget := InputLoopCompareVal.Value == "" ? "1" : InputLoopCompareVal.Value
            Params := "变量 " Obj.matchVar " " Obj.loopOp " " Obj.loopTarget
        } else {
            if (InputSkipOcrArea.Value == "未选择区域" || InputSkipKeyword.Value == "")
                return MsgBox("请框选区域并输入关键词！", "提示", "Icon!")
            RegExMatch(InputSkipOcrArea.Value, "X:(\d+) Y:(\d+) W:(\d+) H:(\d+)", &m)
            Obj.ocrX := Integer(m[1]), Obj.ocrY := Integer(m[2]), Obj.ocrW := Integer(m[3]), Obj.ocrH := Integer(m[4])
            Obj.keyword := InputSkipKeyword.Value
            Params := "OCR包含 [" Obj.keyword "]"
        }
        Obj.skipAction := SkipActionDDL.Text
        Obj.skipN := Integer(InputSkip.Value == "" ? 1 : InputSkip.Value)
        Params .= " → " Obj.skipAction (InStr(Obj.skipAction, "N") ? " (" Obj.skipN ")" : "")
    } else if (t == "🔁 局部循环开始") {
        Obj.loopSrc := LoopSrcDDL.Text
        if (Obj.loopSrc == "固定值") {
            Obj.count := Integer(InputInnerLoop.Value == "" ? 3 : InputInnerLoop.Value)
            Obj.varName := ""
            Params := "固定 " Obj.count " 次"
        } else {
            Obj.count := 0
            Obj.varName := InputLoopVarName.Value == "" ? "LoopCount_OCR" : InputLoopVarName.Value
            Params := "循环次数 ← 变量 " Obj.varName
        }
    } else if (t == "🔚 局部循环结束") {
        Params := "循环结束"
    } else if (t == "🔀 条件分支开始 (If)") {
        Obj.ifType := IfTypeDDL.Text
        if (Obj.ifType == "OCR包含文字") {
            if (InputOcrArea.Value == "未选择区域" || InputSkipKeyword.Value == "")
                return MsgBox("请框选区域并输入关键字！", "提示", "Icon!")
            RegExMatch(InputOcrArea.Value, "X:(\d+) Y:(\d+) W:(\d+) H:(\d+)", &m)
            Obj.ocrX := Integer(m[1]), Obj.ocrY := Integer(m[2]), Obj.ocrW := Integer(m[3]), Obj.ocrH := Integer(m[4])
            Obj.keyword := InputSkipKeyword.Value
            Params := "If (OCR包含 [" Obj.keyword "])"
        } else if (Obj.ifType == "变量匹配") {
            Obj.matchVar := InputVarMatchName.Value == "" ? "CurrentLoop" : InputVarMatchName.Value
            Obj.loopOp := LoopCompareOpDDL.Text
            Obj.loopTarget := InputLoopCompareVal.Value == "" ? "1" : InputLoopCompareVal.Value
            Params := "If (变量 " Obj.matchVar " " Obj.loopOp " " Obj.loopTarget ")"
        } else {
            if (InputSkipColorX.Value == "" || InputSkipColor.Value == "")
                return MsgBox("请设置颜色坐标和值！", "提示", "Icon!")
            Obj.x := Integer(InputSkipColorX.Value), Obj.y := Integer(InputSkipColorY.Value)
            cVal := RegExReplace(InputSkipColor.Value, "(?i)^(0x|#)", "")
            if (!RegExMatch(StrUpper(Trim(cVal)), "^[0-9A-F]{6}$"))
                return MsgBox("颜色值格式错误！", "提示", "Icon!")
            Obj.color := StrUpper(Trim(cVal))
            Params := "If (颜色匹配 " Obj.color ")"
        }
    } else if (t == "🔀 否则 (Else)") {
        Params := "Else"
    } else if (t == "🔀 分支结束 (EndIf)") {
        Params := "EndIf"
    } else if (t == "📝 设置变量") {
        if (InputSetVarName.Value == "")
            return MsgBox("请输入变量名！", "提示", "Icon!")
        if (!RegExMatch(InputSetVarName.Value, "^[A-Za-z_]\w*$"))
            return MsgBox("变量名只能含字母、数字、下划线，且不以数字开头！", "提示", "Icon!")
        Obj.varName := InputSetVarName.Value
        Obj.varValue := InputSetVarValue.Value
        Params := "设置 " Obj.varName " = " Obj.varValue
    } else if (t == "🔍 OCR识别保存文本") {
        if (InputOcrSaveTxtArea.Value == "未选择区域")
            return MsgBox("请框选识别区域！", "提示", "Icon!")
        RegExMatch(InputOcrSaveTxtArea.Value, "X:(\d+) Y:(\d+) W:(\d+) H:(\d+)", &m)
        Obj.ocrX := Integer(m[1]), Obj.ocrY := Integer(m[2]), Obj.ocrW := Integer(m[3]), Obj.ocrH := Integer(m[4])
        Obj.extractMode := ExtractModeDDL.Text
        Obj.extractN := Integer(InputExtractN.Value == "" ? 1 : InputExtractN.Value)
        Obj.filterRegex := InputFilterRe.Value
        Obj.delimiter := DelimiterDDL.Text
        Obj.saveVar := InputSaveTxtVar.Value == "" ? "OCRText" : InputSaveTxtVar.Value
        Params := "保存→" . Obj.saveVar . " (" . Obj.extractMode . ")"
    } else if (t == "🎯 匹配文本并点击") {
        if (InputOcrMatchTxtArea.Value == "未选择区域")
            return MsgBox("请框选匹配区域！", "提示", "Icon!")
        if (InputMatchTxtKeyword.Value == "")
            return MsgBox("请输入匹配内容！", "提示", "Icon!")
        RegExMatch(InputOcrMatchTxtArea.Value, "X:(\d+) Y:(\d+) W:(\d+) H:(\d+)", &m)
        Obj.ocrX := Integer(m[1]), Obj.ocrY := Integer(m[2]), Obj.ocrW := Integer(m[3]), Obj.ocrH := Integer(m[4])
        Obj.keyword := InputMatchTxtKeyword.Value
        Obj.matchMode := MatchTxtModeDDL.Text
        Obj.matchStrategy := MatchTxtStrategyDDL.Text
        Obj.matchN := Integer(InputMatchTxtN.Value == "" ? 1 : InputMatchTxtN.Value)
        Obj.clickPos := MatchTxtPosDDL.Text
        Obj.clickOffX := Integer(InputMatchTxtOffX.Value == "" ? 0 : InputMatchTxtOffX.Value)
        Obj.clickOffY := Integer(InputMatchTxtOffY.Value == "" ? 0 : InputMatchTxtOffY.Value)
        Obj.clickAction := MatchTxtActionDDL.Text
        Obj.findWait := Integer(InputMatchTxtWait.Value == "" ? 0 : InputMatchTxtWait.Value)
        Params := "找[" . Obj.keyword . "] " . Obj.matchMode . "→" . Obj.clickPos
    } else if (t == "📦 调用子脚本") {
        if (InputSubScript.Value == "")
            return MsgBox("请选择子脚本！", "提示", "Icon!")
        if (!FileExist(InputSubScript.Value))
            return MsgBox("子脚本不存在：`n" InputSubScript.Value, "提示", "Icon!")
        Obj.scriptPath := InputSubScript.Value
        Obj.args := InputSubArgs.Value
        Obj.waitMode := SubWaitModeDDL.Text
        Obj.timeout := Integer(InputSubTimeout.Value == "" ? 0 : InputSubTimeout.Value)
        Obj.resultVarName := InputSubResultVar.Value
        Obj.resultFile := InputSubResultFile.Value
        if (Obj.resultVarName != "" && !RegExMatch(Obj.resultVarName, "^[A-Za-z_]\w*$"))
            return MsgBox("结果变量名非法！", "提示", "Icon!")
        Params := "子脚本: " Obj.scriptPath
        if (Obj.args != "")
            Params .= " [" Obj.args "]"
        Params .= " | " Obj.waitMode
        if (Obj.waitMode == "阻塞" && Obj.timeout > 0)
            Params .= " 超时" Obj.timeout "s"
        if (Obj.resultVarName != "")
            Params .= " → {" Obj.resultVarName "}"
    }
    
    if (EditingIndex > 0) {
        TaskArr[EditingIndex] := Obj
        Row := EditingIndex
        EditingIndex := 0
        BtnEdit.Text := "✏ 编辑选中"
        BtnCancelEdit.Visible := False
        StatusBar.SetText("✅ 已保存修改")
    } else {
        Row := LV.GetNext()
        if (IsInsert && Row)
            TaskArr.InsertAt(Row, Obj)
        else {
            TaskArr.Push(Obj)
            Row := TaskArr.Length
        }
    }
    RebuildLV()
    LV.Modify(Row, "Select Vis")
    InputRemark.Value := ""
}

; ================= 列表操作 =================
DeleteTask(*) {
    global TaskArr, EditingIndex
    Row := LV.GetNext()
    if (!Row)
        return MsgBox("请先选中要删除的任务！")
    TaskArr.RemoveAt(Row)
    if (EditingIndex > 0)
        EditingIndex := 0, BtnEdit.Text := "✏ 编辑选中", BtnCancelEdit.Visible := False
    RebuildLV()
    if (TaskArr.Length > 0)
        LV.Modify(Min(Row, TaskArr.Length), "Select Vis")
}

MoveUp(*) {
    global TaskArr, EditingIndex
    Row := LV.GetNext()
    if (!Row || Row == 1)
        return
    Temp := TaskArr[Row], TaskArr[Row] := TaskArr[Row-1], TaskArr[Row-1] := Temp
    if (EditingIndex > 0)
        EditingIndex := 0, BtnEdit.Text := "✏ 编辑选中", BtnCancelEdit.Visible := False
    RebuildLV(), LV.Modify(Row-1, "Select Vis")
}

MoveDown(*) {
    global TaskArr, EditingIndex
    Row := LV.GetNext()
    if (!Row || Row == TaskArr.Length)
        return
    Temp := TaskArr[Row], TaskArr[Row] := TaskArr[Row+1], TaskArr[Row+1] := Temp
    if (EditingIndex > 0)
        EditingIndex := 0, BtnEdit.Text := "✏ 编辑选中", BtnCancelEdit.Visible := False
    RebuildLV(), LV.Modify(Row+1, "Select Vis")
}

RebuildLV() {
    global TaskArr
    LV.Delete()
    for i, obj in TaskArr {
        p := ""
        switch obj.type {
            case "激活窗口":
                p := "激活: " obj.winTitle
                if (obj.HasOwnProp("winWait") && obj.winWait > 0)
                    p .= " (等" obj.winWait "s)"
            case "🚀 启动应用/快捷方式":
                p := "启动: " obj.path
                if (obj.HasOwnProp("args") && obj.args != "")
                    p .= " [" obj.args "]"
                if (obj.HasOwnProp("winTitle") && obj.winTitle != "")
                    p .= " → " obj.winTitle
            case "点击坐标":
                p := "X:" obj.x ", Y:" obj.y " x" (obj.HasOwnProp("clickCount") ? obj.clickCount : 1)
                if (obj.HasOwnProp("offsetX") && (obj.offsetX != 0 || obj.offsetY != 0))
                    p .= " (偏移:" obj.offsetX "," obj.offsetY ")"
                if (obj.HasOwnProp("text") && (obj.text != "" || obj.pasteClip))
                    p .= " → " (obj.pasteClip ? "[粘贴]" : obj.text)
            case "发送按键":
                p := "按键: " obj.key
            case "延时等待":
                p := "等待 " obj.ms " 毫秒"
            case "截图找图":
                act := obj.HasOwnProp("imgAction") ? obj.imgAction : "点击图片中心"
                p := "图片: " obj.path " | " act
                if (obj.HasOwnProp("imgOffX") && (obj.imgOffX != 0 || obj.imgOffY != 0))
                    p .= " (偏移:" obj.imgOffX "," obj.imgOffY ")"
                if (obj.HasOwnProp("imgWait") && obj.imgWait > 0)
                    p .= " (等" obj.imgWait "s)"
            case "识别并填写":
                if (obj.HasOwnProp("saveToVar") && obj.saveToVar)
                    p := "存 " (obj.HasOwnProp("saveVarName") ? obj.saveVarName : "LoopCount_OCR")
                else {
                    tgtCnt := 1
                    if (obj.HasOwnProp("fillX2") && (obj.fillX2 != 0 || obj.fillY2 != 0))
                        tgtCnt := 2
                    if (obj.HasOwnProp("fillX3") && (obj.fillX3 != 0 || obj.fillY3 != 0))
                        tgtCnt := 3
                    p := obj.onlyClip ? "仅剪贴板" : ("填入 " tgtCnt " 处")
                    p .= (obj.HasOwnProp("extractNum") && obj.extractNum) ? " [数字]" : " [原文]"
                    if (obj.HasOwnProp("sendText") && obj.sendText)
                        p .= " [SendText]"
                }
            case "🎲 范围随机填写":
                p := "坐标表 " (obj.decimals == 0 ? "整数" : obj.decimals "位小数")
                if (obj.HasOwnProp("onlyEven") && obj.onlyEven)
                    p .= " [尾数偶数]"
            case "📊 坐标查表填写":
                p := "多坐标查表 (" (obj.HasOwnProp("matchType") ? obj.matchType : "用OCR原文匹配") ")"
            case "🕹️ 条件跳过":
                basis := obj.HasOwnProp("skipBasis") ? obj.skipBasis : "颜色"
                if (basis == "颜色")
                    p := "颜色 (" obj.x "," obj.y ")=" obj.color
                else if (basis == "变量匹配")
                    p := "变量 " (obj.HasOwnProp("matchVar") ? obj.matchVar : "CurrentLoop") " " (obj.HasOwnProp("loopOp") ? obj.loopOp : "==") " " (obj.HasOwnProp("loopTarget") ? obj.loopTarget : "1")
                else
                    p := "OCR包含 [" obj.keyword "]"
                p .= " → " (obj.HasOwnProp("skipAction") ? obj.skipAction : "匹配 → 跳过N步")
                if (obj.HasOwnProp("skipN"))
                    p .= " (" obj.skipN ")"
            case "🔁 局部循环开始":
                if (obj.HasOwnProp("loopSrc") && obj.loopSrc == "变量")
                    p := "循环次数 ← " obj.varName
                else
                    p := "固定循环 " obj.count " 次"
            case "🔚 局部循环结束":
                p := "循环结束"
            case "🔀 条件分支开始 (If)":
                if (obj.ifType == "颜色匹配")
                    p := "If 颜色匹配 (" obj.color ")"
                else if (obj.ifType == "变量匹配")
                    p := "If 变量 " (obj.HasOwnProp("matchVar") ? obj.matchVar : "CurrentLoop") " " (obj.HasOwnProp("loopOp") ? obj.loopOp : "==") " " (obj.HasOwnProp("loopTarget") ? obj.loopTarget : "1")
                else
                    p := "If OCR包含 [" obj.keyword "]"
            case "🔀 否则 (Else)":
                p := "Else"
            case "🔀 分支结束 (EndIf)":
                p := "EndIf"
            case "📝 设置变量":
                p := obj.varName " = " obj.varValue
            case "🔍 OCR识别保存文本":
                p := "保存→" . (obj.HasOwnProp("saveVar") ? obj.saveVar : "OCRText") . " (" . (obj.HasOwnProp("extractMode") ? obj.extractMode : "全部文本") . ")"
            case "🎯 匹配文本并点击":
                p := "找[" . (obj.HasOwnProp("keyword") ? obj.keyword : "") . "] " . (obj.HasOwnProp("matchMode") ? obj.matchMode : "包含") . "→" . (obj.HasOwnProp("clickPos") ? obj.clickPos : "文字中心")
            case "📦 调用子脚本":
                SplitPath obj.scriptPath, &fn
                p := "▶ " fn
                if (obj.HasOwnProp("args") && obj.args != "")
                    p .= " [" obj.args "]"
                p .= " | " (obj.HasOwnProp("waitMode") ? obj.waitMode : "阻塞")
                if (obj.HasOwnProp("resultVarName") && obj.resultVarName != "")
                    p .= " → {" obj.resultVarName "}"
        }
        rmk := obj.HasOwnProp("remark") ? obj.remark : ""
        LV.Add(, i, obj.type, p, rmk)
    }
}

ClearAll(*) {
    global TaskArr, EditingIndex
    if (MsgBox("确定清空所有任务？", "确认", "YesNo Icon?") == "Yes") {
        TaskArr := [], LV.Delete()
        if (EditingIndex > 0)
            EditingIndex := 0, BtnEdit.Text := "✏ 编辑选中", BtnCancelEdit.Visible := False
    }
}

; ================= 保存/读取 =================
SaveConfig(*) {
    global TaskArr, VarPool, FailPolicy, LogEnabled, LogPath
    if (TaskArr.Length == 0)
        return MsgBox("当前没有任务可以保存！", "提示", "Icon!")
    file := FileSelect("S16", A_ScriptDir "\任务配置.ini", "保存任务配置", "配置文件 (*.ini)")
    if (!file)
        return
    if (FileExist(file))
        FileDelete(file)
    try {
        IniWrite(InputLoopCount.Value, file, "Settings", "LoopCount")
        IniWrite(FailPolicy, file, "Settings", "FailPolicy")
        IniWrite(LogEnabled ? "1" : "0", file, "Settings", "LogEnabled")
        IniWrite(LogPath, file, "Settings", "LogPath")
        idx := 0
        for k, v in VarPool {
            idx += 1
            IniWrite(k, file, "VarPool", "key" idx)
            IniWrite(v, file, "VarPool", k)
        }
        for i, obj in TaskArr {
            sec := "Task" i
            for k, v in obj.OwnProps() {
                if (k == "dbIndex" || k == "exec_count")
                    continue
                if (v is Number || v is String)
                    IniWrite(v, file, sec, k)
            }
        }
        CSVCacheClear()
        StatusBar.SetText("✅ 已保存: " file)
    } catch Error as e {
        MsgBox("保存失败: " . e.Message)
    }
}

LoadConfig(*) {
    global TaskArr, EditingIndex, VarPool, FailPolicy, LogEnabled, LogPath
    file := FileSelect(3, A_ScriptDir, "读取任务配置", "配置文件 (*.ini)")
    if (!file)
        return
    try {
        InputLoopCount.Value := IniRead(file, "Settings", "LoopCount", "1")
        fp := IniRead(file, "Settings", "FailPolicy", "stop")
        switch fp {
            case "stop": FailPolicyDDL.Value := 1, FailPolicy := "stop"
            case "skip": FailPolicyDDL.Value := 2, FailPolicy := "skip"
            case "retry1stop": FailPolicyDDL.Value := 3, FailPolicy := "retry1stop"
            case "retry3stop": FailPolicyDDL.Value := 4, FailPolicy := "retry3stop"
            default: FailPolicyDDL.Value := 1, FailPolicy := "stop"
        }
        LogEnabled := (IniRead(file, "Settings", "LogEnabled", "0") == "1")
        ChkLogEnable.Value := LogEnabled
        LogPath := IniRead(file, "Settings", "LogPath", A_ScriptDir "\run.log")
        InputLogPath.Value := LogPath
        UpdateLogUI()
        
        CSVCacheClear()
        
        VarPool := Map("LoopCount_OCR", 0)
        Loop {
            k := IniRead(file, "VarPool", "key" A_Index, "")
            if (k == "")
                break
            VarPool[k] := IniRead(file, "VarPool", k, "0")
        }
        
        TaskArr := []
        Loop {
            sec := "Task" A_Index
            origType := IniRead(file, sec, "type", "")
            if (origType == "")
                break
            if (origType == "输入文本")
                continue
            t := origType
            isOldOcr := false
            if (t == "识别数字并填写") {
                t := "识别并填写"
                isOldOcr := true
            } else if (t == "双击坐标")
                t := "点击坐标"
            else if (t == "点击并输入")
                t := "点击坐标"
            else if (t == "🎨 颜色判断跳过")
                t := "🕹️ 条件跳过"
            else if (t == "👁️ OCR判断")
                t := "🕹️ 条件跳过"
            obj := {type: t}
            
            switch t {
                case "激活窗口":
                    obj.winTitle := IniRead(file, sec, "winTitle", "")
                    obj.winWait := Integer(IniRead(file, sec, "winWait", "0"))
                case "🚀 启动应用/快捷方式":
                    obj.path := IniRead(file, sec, "path", "")
                    obj.args := IniRead(file, sec, "args", "")
                    obj.waitMs := Integer(IniRead(file, sec, "waitMs", "1500"))
                    obj.winTitle := IniRead(file, sec, "winTitle", "")
                case "点击坐标":
                    obj.x := Integer(IniRead(file, sec, "x", "0"))
                    obj.y := Integer(IniRead(file, sec, "y", "0"))
                    obj.offsetX := Integer(IniRead(file, sec, "offsetX", "0"))
                    obj.offsetY := Integer(IniRead(file, sec, "offsetY", "0"))
                    if (origType == "双击坐标")
                        obj.clickCount := 2
                    else
                        obj.clickCount := Integer(IniRead(file, sec, "clickCount", "1"))
                    obj.text := IniRead(file, sec, "text", "")
                    obj.replace := IniRead(file, sec, "replace", "1") == "1"
                    obj.pasteClip := IniRead(file, sec, "pasteClip", "0") == "1"
                case "发送按键":
                    obj.key := IniRead(file, sec, "key", "")
                case "延时等待":
                    obj.ms := Integer(IniRead(file, sec, "ms", "500"))
                case "截图找图":
                    obj.path := IniRead(file, sec, "path", "")
                    obj.sim := Integer(IniRead(file, sec, "sim", "70"))
                    obj.imgAction := IniRead(file, sec, "imgAction", "点击图片中心")
                    obj.imgOffX := Integer(IniRead(file, sec, "imgOffX", "0"))
                    obj.imgOffY := Integer(IniRead(file, sec, "imgOffY", "0"))
                    obj.imgWait := Integer(IniRead(file, sec, "imgWait", "0"))
                case "识别并填写":
                    obj.extractNum := isOldOcr ? true : (IniRead(file, sec, "extractNum", "1") == "1")
                    obj.ocrX := Integer(IniRead(file, sec, "ocrX", "0"))
                    obj.ocrY := Integer(IniRead(file, sec, "ocrY", "0"))
                    obj.ocrW := Integer(IniRead(file, sec, "ocrW", "0"))
                    obj.ocrH := Integer(IniRead(file, sec, "ocrH", "0"))
                    obj.keepDot := IniRead(file, sec, "keepDot", "1") == "1"
                    obj.round1 := IniRead(file, sec, "round1", "0") == "1"
                    obj.onlyClip := IniRead(file, sec, "onlyClip", "0") == "1"
                    obj.mathOp := IniRead(file, sec, "mathOp", "")
                    obj.useDB := IniRead(file, sec, "useDB", "0") == "1"
                    obj.dbPath := IniRead(file, sec, "dbPath", "")
                    obj.fillX := Integer(IniRead(file, sec, "fillX", "0"))
                    obj.fillY := Integer(IniRead(file, sec, "fillY", "0"))
                    obj.fillX2 := Integer(IniRead(file, sec, "fillX2", "0"))
                    obj.fillY2 := Integer(IniRead(file, sec, "fillY2", "0"))
                    obj.fillX3 := Integer(IniRead(file, sec, "fillX3", "0"))
                    obj.fillY3 := Integer(IniRead(file, sec, "fillY3", "0"))
                    obj.sendText := IniRead(file, sec, "sendText", "1") == "1"
                    obj.saveToVar := IniRead(file, sec, "saveToVar", "0") == "1"
                    obj.saveVarName := IniRead(file, sec, "saveVarName", "LoopCount_OCR")
                case "🎲 范围随机填写":
                    obj.ocrX := Integer(IniRead(file, sec, "ocrX", "0"))
                    obj.ocrY := Integer(IniRead(file, sec, "ocrY", "0"))
                    obj.ocrW := Integer(IniRead(file, sec, "ocrW", "0"))
                    obj.ocrH := Integer(IniRead(file, sec, "ocrH", "0"))
                    obj.dbPath := IniRead(file, sec, "dbPath", "")
                    obj.posDBPath := IniRead(file, sec, "posDBPath", "")
                    obj.decimals := Integer(IniRead(file, sec, "decimals", "0"))
                    obj.onlyEven := IniRead(file, sec, "onlyEven", "0") == "1"
                case "📊 坐标查表填写":
                    obj.dbPath := IniRead(file, sec, "dbPath", "")
                    obj.matchType := IniRead(file, sec, "matchType", "用OCR原文匹配")
                case "🕹️ 条件跳过":
                    if (origType == "🎨 颜色判断跳过") {
                        obj.skipBasis := "颜色"
                        obj.x := Integer(IniRead(file, sec, "x", "0"))
                        obj.y := Integer(IniRead(file, sec, "y", "0"))
                        cVal := IniRead(file, sec, "color", "")
                        cVal := RegExReplace(cVal, "(?i)^(0x|#)", "")
                        obj.color := StrUpper(Trim(cVal))
                        obj.skipN := Integer(IniRead(file, sec, "skipCount", "1"))
                        m := IniRead(file, sec, "match", "1") == "1"
                        obj.skipAction := m ? "匹配 → 跳过N步" : "不匹配 → 跳过N步"
                    } else if (origType == "👁️ OCR判断") {
                        obj.skipBasis := "OCR文字"
                        obj.ocrX := Integer(IniRead(file, sec, "ocrX", "0"))
                        obj.ocrY := Integer(IniRead(file, sec, "ocrY", "0"))
                        obj.ocrW := Integer(IniRead(file, sec, "ocrW", "0"))
                        obj.ocrH := Integer(IniRead(file, sec, "ocrH", "0"))
                        obj.keyword := IniRead(file, sec, "keyword", "")
                        obj.skipN := Integer(IniRead(file, sec, "skipCount", "1"))
                        sfm := IniRead(file, sec, "stopIfMatch", "0") == "1"
                        obj.skipAction := sfm ? "匹配 → 彻底停止" : "匹配 → 跳过N步"
                    } else {
                        obj.skipBasis := IniRead(file, sec, "skipBasis", "颜色")
                        obj.skipAction := IniRead(file, sec, "skipAction", "匹配 → 跳过N步")
                        obj.skipN := Integer(IniRead(file, sec, "skipN", "1"))
                        if (obj.skipBasis == "颜色") {
                            obj.x := Integer(IniRead(file, sec, "x", "0"))
                            obj.y := Integer(IniRead(file, sec, "y", "0"))
                            obj.color := IniRead(file, sec, "color", "")
                        } else if (obj.skipBasis == "变量匹配") {
                            obj.matchVar := IniRead(file, sec, "matchVar", "CurrentLoop")
                            obj.loopOp := IniRead(file, sec, "loopOp", "==")
                            obj.loopTarget := IniRead(file, sec, "loopTarget", "1")
                        } else {
                            obj.ocrX := Integer(IniRead(file, sec, "ocrX", "0"))
                            obj.ocrY := Integer(IniRead(file, sec, "ocrY", "0"))
                            obj.ocrW := Integer(IniRead(file, sec, "ocrW", "0"))
                            obj.ocrH := Integer(IniRead(file, sec, "ocrH", "0"))
                            obj.keyword := IniRead(file, sec, "keyword", "")
                        }
                    }
                case "🔁 局部循环开始":
                    obj.loopSrc := IniRead(file, sec, "loopSrc", "固定值")
                    obj.count := Integer(IniRead(file, sec, "count", "3"))
                    obj.varName := IniRead(file, sec, "varName", "LoopCount_OCR")
                case "🔀 条件分支开始 (If)":
                    obj.ifType := IniRead(file, sec, "ifType", "OCR包含文字")
                    if (obj.ifType == "颜色匹配") {
                        obj.x := Integer(IniRead(file, sec, "x", "0"))
                        obj.y := Integer(IniRead(file, sec, "y", "0"))
                        obj.color := IniRead(file, sec, "color", "")
                    } else if (obj.ifType == "变量匹配") {
                        obj.matchVar := IniRead(file, sec, "matchVar", "CurrentLoop")
                        obj.loopOp := IniRead(file, sec, "loopOp", "==")
                        obj.loopTarget := IniRead(file, sec, "loopTarget", "1")
                    } else {
                        obj.ocrX := Integer(IniRead(file, sec, "ocrX", "0"))
                        obj.ocrY := Integer(IniRead(file, sec, "ocrY", "0"))
                        obj.ocrW := Integer(IniRead(file, sec, "ocrW", "0"))
                        obj.ocrH := Integer(IniRead(file, sec, "ocrH", "0"))
                        obj.keyword := IniRead(file, sec, "keyword", "")
                    }
                case "📝 设置变量":
                    obj.varName := IniRead(file, sec, "varName", "")
                    obj.varValue := IniRead(file, sec, "varValue", "")
                case "🔍 OCR识别保存文本":
                    obj.ocrX := Integer(IniRead(file, sec, "ocrX", "0"))
                    obj.ocrY := Integer(IniRead(file, sec, "ocrY", "0"))
                    obj.ocrW := Integer(IniRead(file, sec, "ocrW", "0"))
                    obj.ocrH := Integer(IniRead(file, sec, "ocrH", "0"))
                    obj.extractMode := IniRead(file, sec, "extractMode", "全部文本")
                    obj.extractN := Integer(IniRead(file, sec, "extractN", "1"))
                    obj.filterRegex := IniRead(file, sec, "filterRegex", "")
                    obj.delimiter := IniRead(file, sec, "delimiter", "换行")
                    obj.saveVar := IniRead(file, sec, "saveVar", "OCRText")
                case "🎯 匹配文本并点击":
                    obj.ocrX := Integer(IniRead(file, sec, "ocrX", "0"))
                    obj.ocrY := Integer(IniRead(file, sec, "ocrY", "0"))
                    obj.ocrW := Integer(IniRead(file, sec, "ocrW", "0"))
                    obj.ocrH := Integer(IniRead(file, sec, "ocrH", "0"))
                    obj.keyword := IniRead(file, sec, "keyword", "")
                    obj.matchMode := IniRead(file, sec, "matchMode", "包含")
                    obj.matchStrategy := IniRead(file, sec, "matchStrategy", "第一个")
                    obj.matchN := Integer(IniRead(file, sec, "matchN", "1"))
                    obj.clickPos := IniRead(file, sec, "clickPos", "文字中心")
                    obj.clickOffX := Integer(IniRead(file, sec, "clickOffX", "0"))
                    obj.clickOffY := Integer(IniRead(file, sec, "clickOffY", "0"))
                    obj.clickAction := IniRead(file, sec, "clickAction", "点击")
                    obj.findWait := Integer(IniRead(file, sec, "findWait", "0"))
                case "📦 调用子脚本":
                    obj.scriptPath := IniRead(file, sec, "scriptPath", "")
                    obj.args := IniRead(file, sec, "args", "")
                    obj.waitMode := IniRead(file, sec, "waitMode", "阻塞")
                    obj.timeout := Integer(IniRead(file, sec, "timeout", "0"))
                    obj.resultVarName := IniRead(file, sec, "resultVarName", "")
                    obj.resultFile := IniRead(file, sec, "resultFile", "")
                case "🔚 局部循环结束", "🔀 否则 (Else)", "🔀 分支结束 (EndIf)":
            }
            
            obj.remark := IniRead(file, sec, "remark", "")
            TaskArr.Push(obj)
        }
        RebuildLV()
        if (EditingIndex > 0)
            EditingIndex := 0, BtnEdit.Text := "✏ 编辑选中", BtnCancelEdit.Visible := False
        StatusBar.SetText("✅ 已加载: " file " (" TaskArr.Length " 任务)")
    } catch Error as e {
        MsgBox("读取失败: " . e.Message)
    }
}

; ================= 跳过N步（含结构保护） =================
SkipSteps(curIP, N) {
        global TaskArr
        tempIP := curIP + 1
        nest := 0
        while (N > 0 && tempIP <= TaskArr.Length) {
            tType := TaskArr[tempIP].type
            if (tType == "🔀 条件分支开始 (If)") {
                nest += 1
            } else if (tType == "🔀 分支结束 (EndIf)") {
                if (nest == 0)
                    break
                nest -= 1
            } else if (tType == "🔀 否则 (Else)") {
                if (nest == 0)
                    break
            } else if (tType == "🔚 局部循环结束") {
                if (nest == 0)
                    break
            }
            tempIP += 1
            N -= 1
        }
        return tempIP
}

; ================= 主执行引擎 =================
RunTasks(*) {
    global TaskArr, IsPaused, IsStopped, VarPool, g_RetryCounter, DebugStartIP, OCR_Result, OCR_Keyword, CSVCache
    if (TaskArr.Length == 0)
        return MsgBox("任务队列为空！", "提示", "Icon!")
    if (DebugStartIP > TaskArr.Length)
        DebugStartIP := 1
    
    CSVCache.KeyValues := Map()
    CSVCache.Coords    := Map()
    CSVCache.Range     := Map()
    CSVCache.MultiMap  := Map()
    
    LoopLimit := Integer(InputLoopCount.Value == "" ? 1 : InputLoopCount.Value)
    if (LoopLimit < 0)
        LoopLimit := 1
    IsPaused := false, IsStopped := false
    g_RetryCounter := Map()
    LogWrite("========== 开始执行 (外层" LoopLimit "轮) ==========")
    WinMinimize("ahk_id " MyGui.Hwnd), Sleep(500)
    OuterLoopIdx := 0
    
    try {
        Loop {
            OuterLoopIdx += 1
            if (LoopLimit > 0 && OuterLoopIdx > LoopLimit)
                break
            LogWrite("--- 第 " OuterLoopIdx " 轮 ---")
            for obj in TaskArr {
                if (obj.type == "点击坐标")
                    obj.exec_count := 0
                if (obj.type == "识别并填写")
                    obj.dbIndex := 1
            }
            
            IP := DebugStartIP, LoopStack := [], IfStack := [], StepSafety := 0
            
            While (IP <= TaskArr.Length) {
                if (++StepSafety > 200000) {
                    MsgBox("执行步数过多，脚本强行终止！", "警告")
                    IsStopped := true
                    return
                }
                if (IsStopped)
                    return
                while (IsPaused) {
                    if (IsStopped)
                        return
                    Sleep(50)
                }
                
                obj := TaskArr[IP]
                LogWrite("STEP " IP " [" obj.type "]")
                
                ; =============== 🔁 局部循环开始 ===============
                if (obj.type == "🔁 局部循环开始") {
                    maxCount := 1
                    if (obj.HasOwnProp("loopSrc") && obj.loopSrc == "变量") {
                        varName := obj.HasOwnProp("varName") ? obj.varName : "LoopCount_OCR"
                        if (!VarPool.Has(varName)) {
                            act := HandleFail(IP, obj.type, "变量 " varName " 不存在")
                            if (act == "skip") {
                                IP += 1
                                continue
                            }
                            else if (act == "retry") {
                                SmartSleep(500)
                                continue
                            }
                            else {
                                return
                            }
                        }
                        val := VarPool[varName] + 0
                        if (val < 1) {
                            act := HandleFail(IP, obj.type, "变量 " varName "=" val " 无效(<1)")
                            if (act == "skip") {
                                IP += 1
                                continue
                            }
                            else if (act == "retry") {
                                SmartSleep(500)
                                continue
                            }
                            else {
                                return
                            }
                        }
                        maxCount := val
                    } else {
                        maxCount := obj.count
                    }
                    LoopStack.Push({startIP: IP, max: maxCount, current: 1})
                    LogWrite("  ↳ 循环开始，共 " maxCount " 次")
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                    IP += 1
                    continue
                }
                if (obj.type == "🔚 局部循环结束") {
                    if (LoopStack.Length == 0) {
                        IP += 1
                        continue
                    }
                    top := LoopStack[LoopStack.Length]
                    top.current += 1
                    if (top.current <= top.max) {
                        LogWrite("  ↳ 循环 " top.current "/" top.max)
                        IP := top.startIP + 1
                        continue
                    }
                    LoopStack.Pop()
                    LogWrite("  ↳ 循环结束")
                    IP += 1
                    continue
                }
                
                ; =============== 🔀 If / Else / EndIf ===============
                if (obj.type == "🔀 条件分支开始 (If)") {
                    condResult := false
                    if (obj.ifType == "颜色匹配") {
                        color := PixelGetColor(obj.x, obj.y, "RGB")
                        condResult := (StrUpper(SubStr(color, 3)) = StrUpper(obj.color))
                        LogWrite("  ↳ 颜色(" color ") 目标(" obj.color ") → " (condResult ? "真" : "假"))
                    } else if (obj.ifType == "变量匹配") {
                        matchVar := obj.HasOwnProp("matchVar") ? obj.matchVar : "CurrentLoop"
                        varVal := ""
                        if (matchVar == "CurrentLoop") {
                            varVal := (LoopStack.Length > 0) ? LoopStack[LoopStack.Length].current : OuterLoopIdx
                        } else {
                            varVal := VarPool.Has(matchVar) ? VarPool[matchVar] : ""
                        }
                        targetStr := Interpolate(obj.HasOwnProp("loopTarget") ? obj.loopTarget : "")
                        op := obj.HasOwnProp("loopOp") ? obj.loopOp : "=="
                        condResult := CompareValue(varVal, targetStr, op)
                        LogWrite("  ↳ 变量 " matchVar "(" varVal ") " op " " targetStr " → " (condResult ? "真" : "假"))
                    } else {
                        ocrTxt := OCR_Region(obj.ocrX, obj.ocrY, obj.ocrW, obj.ocrH)
                        OCR_Result := ocrTxt
                        OCR_Keyword := obj.keyword
                        condResult := InStr(ocrTxt, obj.keyword)
                        LogWrite("  ↳ OCR[" ocrTxt "] 含[" obj.keyword "] → " (condResult ? "真" : "假"))
                    }
                    IfStack.Push({ifIP: IP, result: condResult})
                    if (!condResult) {
                        nest := 0, foundElse := false, searchIP := IP + 1
                        while (searchIP <= TaskArr.Length) {
                            tName := TaskArr[searchIP].type
                            if (tName == "🔀 条件分支开始 (If)") {
                                nest += 1
                            } else if (tName == "🔀 分支结束 (EndIf)") {
                                if (nest == 0) {
                                    IP := searchIP
                                    break
                                }
                                nest -= 1
                            } else if (tName == "🔀 否则 (Else)" && nest == 0) {
                                IP := searchIP + 1
                                foundElse := true
                                break
                            }
                            searchIP += 1
                        }
                        if (!foundElse && searchIP > TaskArr.Length) {
                            IP += 1
                            continue
                        }
                        continue
                    }
                    IP += 1
                    continue
                }
                if (obj.type == "🔀 否则 (Else)") {
                    nest := 0, searchIP := IP + 1
                    while (searchIP <= TaskArr.Length) {
                        tName := TaskArr[searchIP].type
                        if (tName == "🔀 条件分支开始 (If)") {
                            nest += 1
                        } else if (tName == "🔀 分支结束 (EndIf)") {
                            if (nest == 0) {
                                IP := searchIP
                                break
                            }
                            nest -= 1
                        }
                        searchIP += 1
                    }
                    if (IfStack.Length > 0)
                        IfStack.Pop()
                    IP += 1
                    continue
                }
                if (obj.type == "🔀 分支结束 (EndIf)") {
                    if (IfStack.Length > 0)
                        IfStack.Pop()
                    IP += 1
                    continue
                }
                
                 ; =============== 激活窗口 ===============
                if (obj.type == "激活窗口") {
                    waitSec := obj.HasOwnProp("winWait") ? obj.winWait : 0
                    success := false
                    
                    if (waitSec > 0) {
                        LogWrite("  ↳ 等 " waitSec "s 内出现：" obj.winTitle)
                        if (!WinWait(obj.winTitle, , waitSec)) {
                            act := HandleFail(IP, obj.type, "等待窗口超时未出现: " obj.winTitle)
                            if (act == "skip") {
                                IP += 1
                                continue
                            } else if (act == "retry") {
                                SmartSleep(800)
                                continue
                            } else {
                                return
                            }
                        }
                    }
                    
                    WinActivate(obj.winTitle)
                    Sleep(200)
                    
                    if (WinActive(obj.winTitle)) {
                        success := true
                    } else {
                        hwnd := WinExist(obj.winTitle)
                        if (hwnd) {
                            WinRestore(obj.winTitle)
                            try DllCall("SetForegroundWindow", "Ptr", hwnd)
                            Sleep(200)
                            if (WinActive(obj.winTitle))
                                success := true
                        }
                    }

                    if (!success) {
                        act := HandleFail(IP, obj.type, "激活失败: " obj.winTitle)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    SmartSleep(500)
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                ; =============== 启动应用 ===============
                else if (obj.type == "🚀 启动应用/快捷方式") {
                    targetPath := obj.path
                    if (!RegExMatch(targetPath, "^(?:[A-Za-z]:[\\/]|\\\\|[A-Za-z]+://)") && FileExist(A_ScriptDir "\" targetPath))
                        targetPath := A_ScriptDir "\" targetPath
                    isUrl := RegExMatch(targetPath, "^[A-Za-z]+://")
                    hasArgs := obj.HasOwnProp("args") && obj.args != ""
                    if (isUrl) {
                        runTarget := targetPath
                    }
                    else if (hasArgs) {
                        runTarget := '"' targetPath '" ' obj.args
                    }
                    else {
                        runTarget := targetPath
                    }
                    try {
                        Run(runTarget)
                        LogWrite("  ↳ 启动成功: " runTarget)
                    } catch Error as e {
                        act := HandleFail(IP, obj.type, "启动失败: " e.Message)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    if (obj.HasOwnProp("winTitle") && obj.winTitle != "") {
                        if (WinWait(obj.winTitle, , 15)) {
                            try WinActivate(obj.winTitle)
                        }
                    } else {
                        SmartSleep(obj.HasOwnProp("waitMs") ? obj.waitMs : 1500)
                    }
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                ; =============== 点击坐标（支持自定义次数） ===============
                else if (obj.type == "点击坐标") {
                    realX := obj.x + (obj.offsetX * obj.exec_count)
                    realY := obj.y + (obj.offsetY * obj.exec_count)
                    MouseMove(realX, realY, 0), SmartSleep(150)
                    if (IsStopped)
                        return
                    clicks := obj.HasOwnProp("clickCount") ? obj.clickCount : 1
                    Loop clicks {
                        Click()
                        if (A_Index < clicks)
                            SmartSleep(50)
                    }
                    if (obj.HasOwnProp("text") && (obj.text != "" || obj.pasteClip)) {
                        SmartSleep(150)
                        if (obj.replace) {
                            Send("^a")
                            SmartSleep(100)
                        }
                        if (obj.pasteClip) {
                            Send("^v")
                            LogWrite("  ↳ 点击后粘贴剪贴板")
                        } else {
                            SendText(Interpolate(obj.text))
                            LogWrite("  ↳ 点击后输入: " obj.text)
                        }
                    }
                    SmartSleep(500)
                    obj.exec_count += 1
                }
                ; =============== 发送按键 ===============
                else if (obj.type == "发送按键") {
                    Send(obj.key), SmartSleep(300)
                }
                ; =============== 延时等待 ===============
                else if (obj.type == "延时等待") {
                    SmartSleep(Integer(obj.ms))
                }
                ; =============== 截图找图（N2 等待） ===============
                else if (obj.type == "截图找图") {
                    simv := obj.HasOwnProp("sim") ? obj.sim : 70
                    imgWait := obj.HasOwnProp("imgWait") ? obj.imgWait : 0
                    found := false, fx := 0, fy := 0
                    
                    if (imgWait > 0) {
                        startT := A_TickCount
                        while (A_TickCount - startT < imgWait * 1000) {
                            if (ImageSearch(&fx, &fy, 0, 0, A_ScreenWidth, A_ScreenHeight, "*" simv " " obj.path)) {
                                found := true
                                break
                            }
                            if (IsStopped)
                                return
                            Sleep(300)
                        }
                    } else {
                        found := ImageSearch(&fx, &fy, 0, 0, A_ScreenWidth, A_ScreenHeight, "*" simv " " obj.path)
                    }
                    
                    if (!found) {
                        errMsg := (imgWait > 0) ? ("等" imgWait "s后仍找不到图片") : "找不到图片"
                        act := HandleFail(IP, obj.type, errMsg "：" obj.path)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    
                    LogWrite("  ↳ 找到图片 @" fx "," fy)
                    action := obj.HasOwnProp("imgAction") ? obj.imgAction : "点击图片中心"
                    offX := obj.HasOwnProp("imgOffX") ? obj.imgOffX : 0
                    offY := obj.HasOwnProp("imgOffY") ? obj.imgOffY : 0
                    clickX := fx + offX, clickY := fy + offY
                    if (action == "点击图片中心") {
                        sz := GetImageSize(obj.path)
                        if (sz[1] > 0 && sz[2] > 0) {
                            clickX := fx + (sz[1] // 2) + offX
                            clickY := fy + (sz[2] // 2) + offY
                        }
                    }
                    MouseMove(clickX, clickY, 0), SmartSleep(150)
                    if (IsStopped)
                        return
                    if (action != "仅移动不点击")
                        Click()
                    SmartSleep(500)
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                ; =============== 识别并填写 ===============
                else if (obj.type == "识别并填写") {
                    ocrTxt := OCR_Region(obj.ocrX, obj.ocrY, obj.ocrW, obj.ocrH)
                    OCR_Result := ocrTxt
                    LogWrite("  ↳ OCR[" ocrTxt "]")
                    
                    if (Trim(ocrTxt) == "") {
                        act := HandleFail(IP, obj.type, "OCR 未识别到任何内容")
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    
                    extractNum := obj.HasOwnProp("extractNum") ? obj.extractNum : true
                    numTxt := ocrTxt
                    if (extractNum) {
                        if (obj.HasOwnProp("keepDot") && obj.keepDot)
                            numTxt := RegExReplace(ocrTxt, "[^0-9\.-]", "")
                        else
                            numTxt := RegExReplace(ocrTxt, "[^0-9-]", "")
                        if (numTxt == "") {
                            act := HandleFail(IP, obj.type, "提取数字后为空（原文：[" ocrTxt "]）")
                            if (act == "skip") {
                                IP += 1
                                continue
                            }
                            else if (act == "retry") {
                                SmartSleep(800)
                                continue
                            }
                            else {
                                return
                            }
                        }
                    }
                    
                    if (obj.HasOwnProp("saveToVar") && obj.saveToVar) {
    varName := obj.HasOwnProp("saveVarName") && obj.saveVarName != "" ? obj.saveVarName : "LoopCount_OCR"
    finalVal := numTxt

    if (RegExMatch(finalVal, "^-?\d+(?:\.\d+)?$")) {
        if (obj.HasOwnProp("mathOp") && Trim(obj.mathOp) != "") {
            mOp := Trim(obj.mathOp)
            op := SubStr(mOp, 1, 1), valStr := Trim(SubStr(mOp, 2))
            if (RegExMatch(op, "^[+\-*/]$") && RegExMatch(valStr, "^-?\d+(?:\.\d+)?$")) {
                n := finalVal + 0
                switch op {
                    case "+": n += valStr + 0
                    case "-": n -= valStr + 0
                    case "*": n *= valStr + 0
                    case "/": n := (valStr + 0 != 0) ? n / (valStr + 0) : n
                }
                finalVal := n
            }
        }
        if (obj.HasOwnProp("round1") && obj.round1)
            finalVal := Round(finalVal + 0, 1)
    }

    if (RegExMatch(finalVal, "^-?\d+(\.\d+)?$"))
        VarPool[varName] := finalVal + 0
    else
        VarPool[varName] := finalVal
    ToolTip("已存入 " varName ": " VarPool[varName], 10, 10), SmartSleep(800)
    LogWrite("  ↳ 变量 " varName " = " VarPool[varName])
    if (g_RetryCounter.Has(IP))
        g_RetryCounter.Delete(IP)
    IP += 1
    continue
}
                    fillValues := []
                    if (obj.useDB && FileExist(obj.dbPath)) {
                        kvMap := LoadKeyValuesCSV(obj.dbPath)
                        if (kvMap.Has(Trim(numTxt)))
                            fillValues := kvMap[Trim(numTxt)]
                    }
                    if (fillValues.Length == 0)
                        fillValues.Push(numTxt)
                    
                    for idx, rawVal in fillValues {
                        if (rawVal != "" && RegExMatch(rawVal, "^-?\d+(?:\.\d+)?$")) {
                            v := rawVal
                            if (obj.HasOwnProp("mathOp") && Trim(obj.mathOp) != "") {
    mOp := Trim(obj.mathOp)
    op := SubStr(mOp, 1, 1), valStr := Trim(SubStr(mOp, 2))
                                if (RegExMatch(op, "^[+\-*/]$") && RegExMatch(valStr, "^-?\d+(?:\.\d+)?$")) {
                                    n := v + 0
                                    switch op {
                                        case "+": n += valStr + 0
                                        case "-": n -= valStr + 0
                                        case "*": n *= valStr + 0
                                        case "/": n := (valStr + 0 != 0) ? n / (valStr + 0) : n
                                    }
                                    v := n
                                }
                            }
                            if (extractNum && obj.HasOwnProp("round1") && obj.round1)
                                v := Round(v + 0, 1)
                            fillValues[idx] := v
                        }
                    }
                    
                    targets := []
                    if (obj.HasOwnProp("fillX") && (obj.fillX != 0 || obj.fillY != 0))
                        targets.Push({x: obj.fillX, y: obj.fillY})
                    if (obj.HasOwnProp("fillX2") && (obj.fillX2 != 0 || obj.fillY2 != 0))
                        targets.Push({x: obj.fillX2, y: obj.fillY2})
                    if (obj.HasOwnProp("fillX3") && (obj.fillX3 != 0 || obj.fillY3 != 0))
                        targets.Push({x: obj.fillX3, y: obj.fillY3})
                    
                    if (obj.onlyClip) {
                        clipVal := (fillValues.Length > 0) ? fillValues[1] : ""
                        if (clipVal == "") {
                            act := HandleFail(IP, obj.type, "无内容可存入剪贴板")
                            if (act == "skip") {
                                IP += 1
                                continue
                            }
                            else if (act == "retry") {
                                SmartSleep(800)
                                continue
                            }
                            else {
                                return
                            }
                        }
                        A_Clipboard := clipVal
                        try ClipWait(1)
                        ToolTip("已存入剪贴板: " clipVal, 10, 10), SmartSleep(500)
                        LogWrite("  ↳ 剪贴板: " clipVal)
                    } else if (targets.Length == 0) {
                        ; 无目标
                    } else if (targets.Length == 1) {
                        if (!obj.HasOwnProp("dbIndex"))
                            obj.dbIndex := 1
                        if (obj.dbIndex < 1 || obj.dbIndex > fillValues.Length)
                            obj.dbIndex := 1
                        pasteVal := fillValues[obj.dbIndex]
                        obj.dbIndex += 1
                        MouseMove(targets[1].x, targets[1].y, 0), SmartSleep(150)
                        if (IsStopped)
                            return
                        Click(), SmartSleep(150)
                        Send("^a")
                        SmartSleep(100)
                        if (obj.HasOwnProp("sendText") && obj.sendText && RegExMatch(pasteVal, "^[\x20-\x7E]+$"))
                            SendText(pasteVal)
                        else
                            FillValue(pasteVal)
                        SmartSleep(300)
                    } else {
                        pasteCount := Min(fillValues.Length, targets.Length)
                        Loop pasteCount {
                            pasteVal := fillValues[A_Index]
                            MouseMove(targets[A_Index].x, targets[A_Index].y, 0), SmartSleep(150)
                            if (IsStopped)
                                return
                            Click(), SmartSleep(150)
                            Send("^a")
                            SmartSleep(100)
                            if (obj.HasOwnProp("sendText") && obj.sendText && RegExMatch(pasteVal, "^[\x20-\x7E]+$"))
                                SendText(pasteVal)
                            else
                                FillValue(pasteVal)
                            SmartSleep(300)
                        }
                    }
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                ; =============== 范围随机 ===============
                else if (obj.type == "🎲 范围随机填写") {
                    ocrTxt := OCR_Region(obj.ocrX, obj.ocrY, obj.ocrW, obj.ocrH)
                    OCR_Result := ocrTxt
                    LogWrite("  ↳ OCR[" ocrTxt "]")
                    if (Trim(ocrTxt) == "") {
                        act := HandleFail(IP, obj.type, "OCR 未识别到内容，无法查范围表")
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    res := FindRangeByKey(obj.dbPath, ocrTxt)
                    if (!res.found) {
                        act := HandleFail(IP, obj.type, "查表失败，OCR原文: 「" ocrTxt "」，CSV: " obj.dbPath)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    coordList := LoadCoordsCSV(obj.posDBPath)
                    if (coordList.Length == 0) {
                        act := HandleFail(IP, obj.type, "坐标表无有效行: " obj.posDBPath)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    minNum := res.min + 0, maxNum := res.max + 0
                    decimals := obj.decimals
                    divisor := 10 ** decimals
                    
                    usedVals := Map()
                    
                    for _, c in coordList {
                        attempts := 0
                        while (true) {
                            if (obj.HasOwnProp("onlyEven") && obj.onlyEven) {
                                minInt := Round(minNum * divisor), maxInt := Round(maxNum * divisor)
                                minEven := Ceil(minInt / 2), maxEven := Floor(maxInt / 2)
                                if (minEven > maxEven) {
                                    randText := Format("{:." . decimals . "f}", minNum)
                                } else {
                                    randInt := Random(minEven, maxEven) * 2
                                    randText := Format("{:." . decimals . "f}", randInt / divisor)
                                }
                            } else if (decimals == 0) {
                                randText := String(Random(Integer(minNum), Integer(maxNum)))
                            } else {
                                randInt := Random(Round(minNum * divisor), Round(maxNum * divisor))
                                randText := Format("{:." . decimals . "f}", randInt / divisor)
                            }
                            
                            attempts += 1
                            totalPossible := (maxNum - minNum) * divisor + 1
                            if (!usedVals.Has(randText) || attempts > 100 || usedVals.Count >= totalPossible)
                                break
                        }
                        usedVals[randText] := true
                        
                        MouseMove(c[1], c[2], 0), SmartSleep(150)
                        if (IsStopped)
                            return
                        Click(), SmartSleep(150)
                        Send("^a")
                        SmartSleep(100)
                        FillValue(randText)
                        SmartSleep(300)
                    }
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                ; =============== 坐标查表 ===============
                else if (obj.type == "📊 坐标查表填写") {
                    if (OCR_Result == "") {
                        act := HandleFail(IP, obj.type, "上一步 OCR 结果为空")
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    if (!FileExist(obj.dbPath)) {
                        act := HandleFail(IP, obj.type, "数据 CSV 不存在: " obj.dbPath)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else {
                            return
                        }
                    }
                    lookupKey := (obj.HasOwnProp("matchType") && obj.matchType == "用包含文字匹配") ? OCR_Keyword : OCR_Result
                    multiMap := LoadMultiMapCSV(obj.dbPath)
                    if (!multiMap.Has(lookupKey)) {
                        ToolTip("⚠️ 查表失败：找不到 [" lookupKey "]，跳过", 10, 10)
                        Sleep(1500)
                        LogWrite("  ⚠️ 关键词 [" lookupKey "] 不存在，跳过")
                    } else {
                        for _, tgt in multiMap[lookupKey] {
                            MouseMove(tgt.x, tgt.y, 0), SmartSleep(150)
                            if (IsStopped)
                                return
                            Click(), SmartSleep(150)
                            Send("^a")
                            SmartSleep(100)
                            FillValue(tgt.value)
                            SmartSleep(300)
                        }
                    }
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                ; =============== 🕹️ 条件跳过（支持变量匹配） ===============
                else if (obj.type == "🕹️ 条件跳过") {
                    isMatched := false
                    if (obj.HasOwnProp("skipBasis") && obj.skipBasis == "OCR文字") {
                        ocrTxt := OCR_Region(obj.ocrX, obj.ocrY, obj.ocrW, obj.ocrH)
                        OCR_Result := ocrTxt
                        OCR_Keyword := obj.keyword
                        isMatched := InStr(ocrTxt, obj.keyword) ? true : false
                        LogWrite("  ↳ OCR[" ocrTxt "] 含[" obj.keyword "] → " (isMatched ? "真" : "假"))
                    } else if (obj.HasOwnProp("skipBasis") && obj.skipBasis == "变量匹配") {
                        matchVar := obj.HasOwnProp("matchVar") ? obj.matchVar : "CurrentLoop"
                        varVal := ""
                        if (matchVar == "CurrentLoop") {
                            varVal := (LoopStack.Length > 0) ? LoopStack[LoopStack.Length].current : OuterLoopIdx
                        } else {
                            varVal := VarPool.Has(matchVar) ? VarPool[matchVar] : ""
                        }
                        targetStr := Interpolate(obj.HasOwnProp("loopTarget") ? obj.loopTarget : "")
                        op := obj.HasOwnProp("loopOp") ? obj.loopOp : "=="
                        isMatched := CompareValue(varVal, targetStr, op)
                        LogWrite("  ↳ 变量 " matchVar "(" varVal ") " op " " targetStr " → " (isMatched ? "真" : "假"))
                    } else {
                        color := PixelGetColor(obj.x, obj.y, "RGB")
                        isMatched := (StrUpper(SubStr(color, 3)) = StrUpper(obj.color))
                        LogWrite("  ↳ 颜色(" color ") 目标(" obj.color ") → " (isMatched ? "真" : "假"))
                    }
                    skipAction := obj.HasOwnProp("skipAction") ? obj.skipAction : "匹配 → 跳过N步"
                    skipN := obj.HasOwnProp("skipN") ? obj.skipN : 1
                    
                    if (skipAction == "匹配 → 彻底停止") {
                        if (isMatched) {
                            IsStopped := true
                            ToolTip("⏹ 条件匹配，任务已停止", 10, 10), Sleep(1500)
                            LogWrite("  ⏹ 条件匹配 → 停止")
                            return
                        }
                    } else if (skipAction == "匹配 → 跳过N步") {
                        if (isMatched) {
                            IP := SkipSteps(IP, skipN)
                            LogWrite("  ⏭ 匹配 → 跳过 " skipN " 步")
                            continue
                        }
                    } else {
                        if (!isMatched) {
                            IP := SkipSteps(IP, skipN)
                            LogWrite("  ⏭ 不匹配 → 跳过 " skipN " 步")
                            continue
                        }
                    }
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                ; =============== 📝 设置变量 ===============
                else if (obj.type == "📝 设置变量") {
                    varName := obj.varName
                    if (!RegExMatch(varName, "^[A-Za-z_]\w*$")) {
                        act := HandleFail(IP, obj.type, "变量名非法: " varName)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    finalVal := Interpolate(obj.varValue)
                    if (RegExMatch(finalVal, "^-?\d+(\.\d+)?$"))
                        VarPool[varName] := finalVal + 0
                    else
                        VarPool[varName] := finalVal
                    ToolTip("📝 " varName " = " VarPool[varName], 10, 10), SmartSleep(600)
                    LogWrite("  ↳ 设置变量 " varName " = " VarPool[varName])
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                ; =============== 📦 调用子脚本 ===============
; =============== 🔍 OCR识别保存文本 ===============
else if (obj.type == "🔍 OCR识别保存文本") {
    __items := OCR_RegionDetailed(obj.ocrX, obj.ocrY, obj.ocrW, obj.ocrH)
    if (__items.Length == 0) {
        act := HandleFail(IP, obj.type, "OCR 无识别结果")
        if (act == "skip") {
            IP += 1
            continue
        }
        else if (act == "retry") {
            SmartSleep(800)
            continue
        }
        else return
    }

    texts := []
    Loop __items.Length {
        texts.Push(__items[A_Index].text)
    }

    mode := obj.extractMode
    filterRe := obj.filterRegex
    delimStr := Chr(10)
    if (obj.delimiter == "逗号")
        delimStr := ","
    else if (obj.delimiter == "空格")
        delimStr := " "
    else if (obj.delimiter == "制表符")
        delimStr := Chr(9)

    finalText := ""
    count := 0

    if (mode == "全部文本") {
        filtered := []
        Loop texts.Length {
            t := texts[A_Index]
            if (filterRe == "" || RegExMatch(t, filterRe))
                filtered.Push(t)
        }
        count := filtered.Length
        Loop filtered.Length {
            if (A_Index > 1)
                finalText .= delimStr
            finalText .= filtered[A_Index]
        }
    } else if (mode == "第N项") {
        n := obj.extractN
        if (n >= 1 && n <= texts.Length) {
            finalText := texts[n]
            count := 1
        }
    } else if (mode == "首个匹配正则") {
        Loop texts.Length {
            if (RegExMatch(texts[A_Index], filterRe, &mm)) {
                finalText := mm[0]
                count := 1
                break
            }
        }
    } else if (mode == "全部匹配正则") {
        allMatches := []
        Loop texts.Length {
            p := 1
            src := texts[A_Index]
            while (p <= StrLen(src)) {
                if (!RegExMatch(SubStr(src, p), filterRe, &mm))
                    break
                allMatches.Push(mm[0])
                p += mm.Pos - 1 + mm.Len
                if (mm.Len == 0)
                    p += 1
            }
        }
        count := allMatches.Length
        Loop allMatches.Length {
            if (A_Index > 1)
                finalText .= delimStr
            finalText .= allMatches[A_Index]
        }
    }

    if (finalText == "") {
        act := HandleFail(IP, obj.type, "提取结果为空（识别 " . texts.Length . " 项）")
        if (act == "skip") {
            IP += 1
            continue
        }
        else if (act == "retry") {
            SmartSleep(800)
            continue
        }
        else return
    }

    saveVarName := obj.saveVar == "" ? "OCRText" : obj.saveVar
    VarPool[saveVarName] := finalText
    VarPool[saveVarName . "_Count"] := count

    preview := finalText
    if (StrLen(preview) > 40)
        preview := SubStr(preview, 1, 40) . "..."
    ToolTip("🔍 " . saveVarName . " = " . preview, 10, 10)
    LogWrite("  ↳ 识别保存 " . saveVarName . " (count=" . count . ")")
    SmartSleep(600)
    if (g_RetryCounter.Has(IP))
        g_RetryCounter.Delete(IP)
}
; =============== 🎯 匹配文本并点击 ===============
else if (obj.type == "🎯 匹配文本并点击") {
    kw := Interpolate(obj.keyword)
    mode := obj.matchMode
    strategy := obj.matchStrategy
    matchN := obj.HasOwnProp("matchN") ? obj.matchN : 1
    findWait := obj.findWait
    deadline := A_TickCount + findWait * 1000

    matches := []
    Loop {
        __items := OCR_RegionDetailed(obj.ocrX, obj.ocrY, obj.ocrW, obj.ocrH)
        matches := []
        Loop __items.Length {
            item := __items[A_Index]
            hit := false
            if (mode == "完全等于") {
                hit := (item.text == kw)
            } else if (mode == "正则") {
                try {
                    hit := RegExMatch(item.text, kw) ? true : false
                } catch {
                    hit := false
                }
            } else {
                hit := InStr(item.text, kw) ? true : false
            }
            if (hit)
                matches.Push(item)
        }
        if (matches.Length > 0)
            break
        if (findWait == 0 || A_TickCount >= deadline)
            break
        if (IsStopped)
            return
        SmartSleep(300)
    }

    if (matches.Length == 0) {
        act := HandleFail(IP, obj.type, "找不到关键词 [" . kw . "]")
        if (act == "skip") {
            IP += 1
            continue
        }
        else if (act == "retry") {
            SmartSleep(800)
            continue
        }
        else return
    }

    posMode := obj.clickPos
    offX := obj.clickOffX
    offY := obj.clickOffY
    clickAct := obj.clickAction

    if (strategy == "全部") {
        Loop matches.Length {
            item := matches[A_Index]
            cx := item.cx
            cy := item.cy
            if (posMode == "左上角") {
                cx := item.x
                cy := item.y
            } else if (posMode == "右下角") {
                cx := item.x + item.w
                cy := item.y + item.h
            } else if (posMode == "右侧中点") {
                cx := item.x + item.w + 5
                cy := item.cy
            }
            cx += offX
            cy += offY
            LogWrite("  🎯 点击 [" . item.text . "] @ " . cx . "," . cy)
            MouseMove(cx, cy, 0)
            SmartSleep(150)
            if (IsStopped)
                return
            if (clickAct != "仅移动不点击")
                Click()
            SmartSleep(400)
        }
    } else {
        idx := 1
        if (strategy == "第N个")
            idx := matchN
        if (idx < 1 || idx > matches.Length)
            idx := 1
        item := matches[idx]
        cx := item.cx
        cy := item.cy
        if (posMode == "左上角") {
            cx := item.x
            cy := item.y
        } else if (posMode == "右下角") {
            cx := item.x + item.w
            cy := item.y + item.h
        } else if (posMode == "右侧中点") {
            cx := item.x + item.w + 5
            cy := item.cy
        }
        cx += offX
        cy += offY
        LogWrite("  🎯 点击 [" . item.text . "] @ " . cx . "," . cy)
        MouseMove(cx, cy, 0)
        SmartSleep(150)
        if (IsStopped)
            return
        if (clickAct != "仅移动不点击")
            Click()
        SmartSleep(400)
    }
    if (g_RetryCounter.Has(IP))
        g_RetryCounter.Delete(IP)
}
                else if (obj.type == "📦 调用子脚本") {
                    scriptPath := Interpolate(obj.scriptPath)
                    if (!FileExist(scriptPath)) {
                        act := HandleFail(IP, obj.type, "子脚本不存在: " scriptPath)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else return
                    }

                    resultFile := obj.HasOwnProp("resultFile") ? Interpolate(obj.resultFile) : ""
                    if (resultFile == "")
                        resultFile := A_Temp . "\subresult_" . A_TickCount . ".ini"
                    try FileDelete(resultFile)

                    argsStr := Interpolate(obj.HasOwnProp("args") ? obj.args : "")
                    
                    if (SubStr(StrLower(scriptPath), -3) == ".exe") {
                        cmd := '"' scriptPath '"'
                    } else {
                        cmd := '"' A_AhkPath '" "' scriptPath '"'
                    }
                    if (argsStr != "")
                        cmd .= " " argsStr
                    cmd .= ' "' resultFile '"'

                    LogWrite("  ↳ 启动子脚本: " cmd)
                    try {
                        pid := Run(cmd)
                    } catch Error as e {
                        act := HandleFail(IP, obj.type, "启动失败: " e.Message)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else return
                    }

                    waitMode := obj.HasOwnProp("waitMode") ? obj.waitMode : "阻塞"
                    if (waitMode == "不等待") {
                        LogWrite("  ↳ 非阻塞，立即继续")
                        IP += 1
                        continue
                    }

                    startT := A_TickCount
                    timeout := obj.HasOwnProp("timeout") ? obj.timeout : 0
                    killed := false
                    while (ProcessExist(pid)) {
                        if (IsStopped) {
                            try ProcessClose(pid)
                            LogWrite("  ↳ 用户中断，已结束子脚本")
                            return
                        }
                        if (timeout > 0 && (A_TickCount - startT) > timeout * 1000) {
                            try ProcessClose(pid)
                            killed := true
                            break
                        }
                        SmartSleep(200)
                    }

                    if (killed) {
                        act := HandleFail(IP, obj.type, "子脚本超时(" timeout "s)，已强制结束")
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else return
                    }

                    Sleep(100)
                    if (FileExist(resultFile)) {
                        status := IniRead(resultFile, "result", "status", "")
                        value := IniRead(resultFile, "result", "value", "")
                        if (status == "ok") {
                            LogWrite("  ↳ 子脚本成功，value=[" value "]")
                            if (obj.HasOwnProp("resultVarName") && obj.resultVarName != "")
                                VarPool[obj.resultVarName] := value
                        } else if (status == "fail") {
                            msg := IniRead(resultFile, "result", "message", "")
                            act := HandleFail(IP, obj.type, "子脚本报告失败: " msg)
                            try FileDelete(resultFile)
                            if (act == "skip") {
                                IP += 1
                                continue
                            }
                            else if (act == "retry") {
                                SmartSleep(800)
                                continue
                            }
                            else return
                        } else {
                            LogWrite("  ↳ 子脚本结束（结果文件无 status 字段，视为成功）")
                        }
                        try FileDelete(resultFile)
                    } else {
                        LogWrite("  ↳ 子脚本结束（未产生结果文件）")
                    }
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                
                IP += 1
            }
        }
        if (!IsStopped) {
            ToolTip("✅ 所有任务执行完毕！", 10, 10)
            LogWrite("========== 全部完成 ==========")
            Sleep(2000)
        }
    } finally {
        ToolTip()
        WinRestore("ahk_id " MyGui.Hwnd)
    }
}

; ================= 导出独立脚本 =================
ExportToAhkSafe(*) {
    global TaskArr, FailPolicy, LogEnabled, LogPath
    if (TaskArr.Length == 0)
        return MsgBox("当前没有任务可以导出！", "提示", "Icon!")

    file := FileSelect("S16", A_ScriptDir "\独立自动化脚本.ahk", "导出独立执行脚本", "AHK脚本 (*.ahk)")
    if (!file)
        return
    if (FileExist(file))
        FileDelete(file)

    ; 【修复】AHK v2 转义规则：只需把 " 换成 ""，反斜杠保留原样
    q := Chr(34)
    tasksCode := "global TaskArr := []`n"
    for i, obj in TaskArr {
        tasksCode .= "t" i " := {type: " q obj.type q "}`n"
        for k, v in obj.OwnProps() {
            if (k == "type" || k == "dbIndex" || k == "exec_count" || k == "remark")
                continue
            if (v is Integer || v is Float) {
                tasksCode .= "t" i "." k " := " v "`n"
            } else {
                safeVal := StrReplace(String(v), q, q q)
                tasksCode .= "t" i "." k " := " q safeVal q "`n"
            }
        }
        tasksCode .= "TaskArr.Push(t" i ")`n`n"
    }

    loopLimitVal := (InputLoopCount.Value == "" ? 1 : InputLoopCount.Value)
    if (Integer(loopLimitVal) < 0)
        loopLimitVal := 1
    logBool := LogEnabled ? "true" : "false"
    logPathSafe := StrReplace(LogPath, q, q q)   ; 【修复】不再转义反斜杠

    engineCode := '
    (
    #Requires AutoHotkey v2.0
    #SingleInstance Force
    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")
    try DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
    SendMode("Input")

    global IsPaused := false
    global IsStopped := false
    global LoopLimit := {{__LOOPLIMIT__}}
    global VarPool := Map("LoopCount_OCR", 0)
    global g_RetryCounter := Map()
    global FailPolicy := "{{__FAILPOLICY__}}"
    global LogEnabled := {{__LOGENABLED__}}
    global LogPath := "{{__LOGPATH__}}"
    global OCR_Result := ""
    global OCR_Keyword := ""
    global CSVCache := Map("KeyValues", Map(), "Coords", Map(), "Range", Map(), "MultiMap", Map())

    {{__TASKSCODE__}}

    F3:: {
        global IsPaused
        IsPaused := !IsPaused
        if (IsPaused)
            ToolTip("⏸️ 任务已暂停", 10, 10)
        else
            ToolTip("▶ 任务继续", 10, 10)
    }
    F2:: {
        global IsStopped, IsPaused
        if (IsStopped)
            return
        IsStopped := true, IsPaused := false
        ToolTip("⏹ 已中断！", 10, 10)
        SetTimer(() => ToolTip(), -3000)
    }
    F4:: ExitApp

    SmartSleep(ms) {
        global IsPaused, IsStopped
        startTime := A_TickCount
        while (A_TickCount - startTime < ms) {
            if (IsStopped)
                return
            if (IsPaused) {
                while (IsPaused) {
                    if (IsStopped)
                        return
                    Sleep(50)
                }
            }
            Sleep(20)
        }
    }

    Interpolate(str) {
        global VarPool
        if (str == "")
            return str
        out := str
        Loop 5 {
            built := ""
            pos := 1
            while (RegExMatch(out, "\{([A-Za-z_]\w*)\}", &m, pos)) {
                varName := m[1]
                built .= SubStr(out, pos, m.Pos - pos)
                if (VarPool.Has(varName))
                    built .= VarPool[varName]
                else
                    built .= m[0]
                pos := m.Pos + m.Len
            }
            built .= SubStr(out, pos)
            if (built == out)
                break
            out := built
        }
        return out
    }

    CompareValue(val1, val2, op) {
        if (op == "包含")
            return InStr(val1, val2) ? true : false
        if (op == "是N的倍数") {
            if (IsNumber(val1) && IsNumber(val2) && (val2 + 0 != 0))
                return Mod(val1 + 0, val2 + 0) == 0
            return false
        }
        
        if (IsNumber(val1) && IsNumber(val2)) {
            v1 := val1 + 0, v2 := val2 + 0
            switch op {
                case "==": return v1 == v2
                case "!=": return v1 != v2
                case ">":  return v1 > v2
                case "<":  return v1 < v2
                case ">=": return v1 >= v2
                case "<=": return v1 <= v2
            }
        } else {
            switch op {
                case "==": return val1 == val2
                case "!=": return val1 != val2
                default: return false
            }
        }
        return false
    }

    LogWrite(msg) {
        global LogEnabled, LogPath
        if (!LogEnabled)
            return
        try FileAppend("[" FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") "] " msg Chr(10), LogPath, "UTF-8")
    }

    SkipSteps(curIP, N) {
        global TaskArr
        tempIP := curIP + 1
        nest := 0
        while (N > 0 && tempIP <= TaskArr.Length) {
            tType := TaskArr[tempIP].type
            if (tType == "🔀 条件分支开始 (If)") {
                nest += 1
            } else if (tType == "🔀 分支结束 (EndIf)") {
                if (nest == 0)
                    break
                nest -= 1
            } else if (tType == "🔀 否则 (Else)") {
                if (nest == 0)
                    break
            } else if (tType == "🔚 局部循环结束") {
                if (nest == 0)
                    break
            }
            tempIP += 1
            N -= 1
        }
        return tempIP
    }

    HandleFail(stepIP, stepType, errMsg) {
        global FailPolicy, IsStopped, g_RetryCounter
        LogWrite("FAIL 步骤" stepIP " | " stepType " | " errMsg)
        cur := g_RetryCounter.Has(stepIP) ? g_RetryCounter[stepIP] : 0
        switch FailPolicy {
            case "skip":
                ToolTip("⚠️ 步骤" stepIP "失败，跳过：" errMsg, 10, 10)
                Sleep(800)
                return "skip"
            case "retry1stop":
                if (cur < 1) {
                    g_RetryCounter[stepIP] := cur + 1
                    ToolTip("⚠️ 步骤" stepIP "失败，重试中：" errMsg, 10, 10)
                    Sleep(800)
                    return "retry"
                }
                MsgBox("步骤" stepIP " 重试1次后仍失败：" Chr(10) errMsg, "失败", "Iconx")
                IsStopped := true
                return "stop"
            case "retry3stop":
                if (cur < 3) {
                    g_RetryCounter[stepIP] := cur + 1
                    ToolTip("⚠️ 步骤" stepIP "失败，重试 " (cur+1) "/3：" errMsg, 10, 10)
                    Sleep(800)
                    return "retry"
                }
                MsgBox("步骤" stepIP " 重试3次后仍失败：" Chr(10) errMsg, "失败", "Iconx")
                IsStopped := true
                return "stop"
            default:
                MsgBox("步骤" stepIP " 失败：" Chr(10) errMsg, "失败", "Iconx")
                IsStopped := true
                return "stop"
        }
    }

    GetImageSize(path) {
        SplitPath(path, , , &ext)
        ext := StrLower(ext)
        f := 0
        try f := FileOpen(path, "r")
        catch
            return [0, 0]
        if (!f)
            return [0, 0]
        try {
            if (ext == "bmp") {
                buf := Buffer(30, 0)
                f.RawRead(buf, 30)
                return [Abs(NumGet(buf, 18, "Int")), Abs(NumGet(buf, 22, "Int"))]
            } else if (ext == "png") {
                buf := Buffer(24, 0)
                f.RawRead(buf, 24)
                return [NumGet(buf, 16, "UInt"), NumGet(buf, 20, "UInt")]
            } else if (ext == "gif") {
                buf := Buffer(10, 0)
                f.RawRead(buf, 10)
                return [NumGet(buf, 6, "UShort"), NumGet(buf, 8, "UShort")]
            }
        } catch {
        } finally {
            f.Close()
        }
        return [0, 0]
    }

    CaptureAreaFile(x, y, w, h, filePath) {
        hDC := DllCall("GetDC", "Ptr", 0, "Ptr"), hMemDC := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
        hBmp := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", w, "Int", h)
        DllCall("SelectObject", "Ptr", hMemDC, "Ptr", hBmp)
        DllCall("BitBlt", "Ptr", hMemDC, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hDC, "Int", x, "Int", y, "UInt", 0x00CC0020)
        bmi := Buffer(40, 0)
        NumPut("UInt", 40, bmi, 0), NumPut("Int", w, bmi, 4), NumPut("Int", -h, bmi, 8), NumPut("Short", 1, bmi, 12), NumPut("Short", 24, bmi, 14)
        rowSize := Ceil(w * 3 / 4) * 4, imgSize := rowSize * h
        imgData := Buffer(imgSize, 0)
        DllCall("GetDIBits", "Ptr", hMemDC, "Ptr", hBmp, "UInt", 0, "UInt", h, "Ptr", imgData, "Ptr", bmi, "UInt", 0)
        fileHeader := Buffer(14, 0)
        NumPut("UShort", 0x4D42, fileHeader, 0), NumPut("UInt", 14 + 40 + imgSize, fileHeader, 2), NumPut("UInt", 14 + 40, fileHeader, 10)
        File := FileOpen(filePath, "w"), File.RawWrite(fileHeader, 14), File.RawWrite(bmi, 40), File.RawWrite(imgData, imgSize), File.Close()
        DllCall("DeleteObject", "Ptr", hBmp), DllCall("DeleteDC", "Ptr", hMemDC), DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
        return FileExist(filePath)
    }

    DoOCR_File(ImagePath) {
        try {
            FileData := FileRead(ImagePath, "RAW")
            Size := 0
            DllCall("Crypt32.dll\CryptBinaryToStringW", "Ptr", FileData.Ptr, "UInt", FileData.Size, "UInt", 1, "Ptr", 0, "UInt*", &Size)
            Base64Buf := Buffer(Size * 2)
            DllCall("Crypt32.dll\CryptBinaryToStringW", "Ptr", FileData.Ptr, "UInt", FileData.Size, "UInt", 1, "Ptr", Base64Buf, "UInt*", &Size)
            B64Str := StrGet(Base64Buf, "UTF-16")
            B64Str := StrReplace(StrReplace(B64Str, Chr(13), ""), Chr(10), "")

            payload := "{" . Chr(34) . "base64" . Chr(34) . ": " . Chr(34) . B64Str . Chr(34) . "}"

            tmpReq := A_Temp . "\OCR_Req_" . A_TickCount . "_" . Random(1000, 9999) . ".json"
            tmpRes := A_Temp . "\OCR_Res_" . A_TickCount . "_" . Random(1000, 9999) . ".json"
            FileAppend(payload, tmpReq, "UTF-8-RAW")
            Sleep(50)

            curlPath := ""
            for _, candidate in [
                A_ScriptDir "\curl.exe",
                A_ScriptDir "\curl-8.23.0_1-win64-mingw\bin\curl.exe",
                A_WinDir "\System32\curl.exe",
                A_WinDir "\Sysnative\curl.exe",
                "curl.exe"
            ] {
                if FileExist(candidate) {
                    curlPath := candidate
                    break
                }
            }
            if (curlPath == "") {
                LogWrite("❌ DoOCR_File: 未找到 curl.exe")
                ToolTip("❌ OCR 引擎缺失：未找到 curl.exe", 10, 10)
                SetTimer(() => ToolTip(), -3000)
                try FileDelete(tmpReq)
                return ""
            }

            cmd := Chr(34) . curlPath . Chr(34) . " -m 15 -s -X POST " . Chr(34) . "http://127.0.0.1:1224/api/ocr" . Chr(34) . " -H " . Chr(34) . "Content-Type: application/json" . Chr(34) . " --data-binary " . Chr(34) . "@" . tmpReq . Chr(34) . " -o " . Chr(34) . tmpRes . Chr(34)
            RunWait(cmd, A_Temp, "Hide")

            respText := ""
            if (FileExist(tmpRes)) {
                respText := FileRead(tmpRes, "UTF-8")
                FileDelete(tmpRes)
            }
            FileDelete(tmpReq)

            if (respText != "") {
                result := "", pos := 1
                while (RegExMatch(SubStr(respText, pos), '"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)) {
                    textChunk := m[1]
                    textChunk := _DecodeUnicode(textChunk)
                    result .= textChunk
                    pos := pos + m.Pos - 1 + m.Len
                }
                return Trim(result)
            }
            return ""
        } catch {
            return ""
    }
}

    OCR_Region(x, y, w, h) {
        tmpImg := A_Temp . "\OCR_R_" . A_TickCount . "_" . Random(1000, 9999) . ".bmp"
        CaptureAreaFile(x, y, w, h, tmpImg)
        txt := DoOCR_File(tmpImg)
        try FileDelete(tmpImg)
        return Trim(txt)
    }

    ; ===== 解析 OCR JSON，返回 [{text, box, x, y, w, h, cx, cy}, ...] =====
    DoOCR_File_Detailed(ImagePath) {
        try {
            FileData := FileRead(ImagePath, "RAW")
            Size := 0
            DllCall("Crypt32.dll\CryptBinaryToStringW", "Ptr", FileData.Ptr, "UInt", FileData.Size, "UInt", 1, "Ptr", 0, "UInt*", &Size)
            Base64Buf := Buffer(Size * 2)
            DllCall("Crypt32.dll\CryptBinaryToStringW", "Ptr", FileData.Ptr, "UInt", FileData.Size, "UInt", 1, "Ptr", Base64Buf, "UInt*", &Size)
            B64Str := StrGet(Base64Buf, "UTF-16")
            B64Str := StrReplace(StrReplace(B64Str, Chr(13), ""), Chr(10), "")
            payload := "{" . Chr(34) . "base64" . Chr(34) . ": " . Chr(34) . B64Str . Chr(34) . "}"
            tmpReq := A_Temp . "\OCR_Req_" . A_TickCount . "_" . Random(1000, 9999) . ".json"
            tmpRes := A_Temp . "\OCR_Res_" . A_TickCount . "_" . Random(1000, 9999) . ".json"
            FileAppend(payload, tmpReq, "UTF-8-RAW")
            Sleep(50)
            curlPath := ""
            for _, c in [A_ScriptDir "\curl.exe",
                         A_ScriptDir "\curl-8.23.0_1-win64-mingw\bin\curl.exe",
                         A_WinDir "\System32\curl.exe",
                         A_WinDir "\Sysnative\curl.exe",
                         "curl.exe"] {
                if FileExist(c) {
                    curlPath := c
                    break
                }
            }
            if (curlPath == "") {
                try FileDelete(tmpReq)
                return []
            }
            cmd := Chr(34) . curlPath . Chr(34) . " -m 15 -s -X POST " . Chr(34) . "http://127.0.0.1:1224/api/ocr" . Chr(34) . " -H " . Chr(34) . "Content-Type: application/json" . Chr(34) . " --data-binary " . Chr(34) . "@" . tmpReq . Chr(34) . " -o " . Chr(34) . tmpRes . Chr(34)
            RunWait(cmd, A_Temp, "Hide")
            respText := ""
            if (FileExist(tmpRes)) {
                respText := FileRead(tmpRes, "UTF-8")
                FileDelete(tmpRes)
            }
            FileDelete(tmpReq)
            if (respText == "")
                return []
            texts := []
            pos := 1
            while (RegExMatch(SubStr(respText, pos), '"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)) {
                texts.Push(_DecodeUnicode(m[1]))
                pos := pos + m.Pos - 1 + m.Len
            }
            boxes := []
            pos := 1
            while (RegExMatch(SubStr(respText, pos),
                '"box"\s*:\s*\[\s*\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]\s*,\s*\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]\s*,\s*\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]\s*,\s*\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]\s*\]', &m)) {
                boxes.Push([[Integer(m[1]), Integer(m[2])],
                            [Integer(m[3]), Integer(m[4])],
                            [Integer(m[5]), Integer(m[6])],
                            [Integer(m[7]), Integer(m[8])]])
                pos := pos + m.Pos - 1 + m.Len
            }
            items := []
            if (texts.Length == 0)
                return items
            if (texts.Length != boxes.Length) {
                for t in texts
                    items.Push({text: t, box: [], x: 0, y: 0, w: 0, h: 0, cx: 0, cy: 0})
                return items
            }
            Loop texts.Length {
                i := A_Index
                box := boxes[i]
                minX := box[1][1]
                maxX := box[1][1]
                minY := box[1][2]
                maxY := box[1][2]
                Loop box.Length {
                    pt := box[A_Index]
                    xv := pt[1]
                    yv := pt[2]
                    if (xv < minX)
                        minX := xv
                    if (xv > maxX)
                        maxX := xv
                    if (yv < minY)
                        minY := yv
                    if (yv > maxY)
                        maxY := yv
                }
                items.Push({
                    text: texts[i], box: box,
                    x: minX, y: minY, w: maxX - minX, h: maxY - minY,
                    cx: (minX + maxX) // 2, cy: (minY + maxY) // 2
                })
            }
            return items
        } catch {
            return []
        }
    }

    OCR_RegionDetailed(x, y, w, h) {
        tmpImg := A_Temp . "\OCR_" . A_TickCount . "_" . Random(1000, 9999) . ".bmp"
        CaptureAreaFile(x, y, w, h, tmpImg)
        items := DoOCR_File_Detailed(tmpImg)
        try FileDelete(tmpImg)
        Loop items.Length {
            item := items[A_Index]
            item.x += x
            item.y += y
            item.cx += x
            item.cy += y
            Loop item.box.Length {
                pt := item.box[A_Index]
                pt[1] += x
                pt[2] += y
            }
        }
        return items
    }

    FillValue(text) {
        if (RegExMatch(text, "^[\x20-\x7E]+$")) {
            SendText(text)
            return
        }
        try {
            A_Clipboard := text
            if (!ClipWait(1)) {
                Sleep(100)
                A_Clipboard := text
                ClipWait(1)
            }
        } catch {
            Sleep(100)
            try A_Clipboard := text
        }
        Send("^v")
    }

    _DecodeUnicode(text) {
        while RegExMatch(text, "\\u([0-9a-fA-F]{4})", &m) {
            text := StrReplace(text, "\u" . m[1], Chr(Integer("0x" . m[1])))
        }
        return text
    }

    FindRangeByKey(csvPath, ocrTxt) {
        global CSVCache
        cacheKey := csvPath . "|||" . ocrTxt
        if (CSVCache.Range.Has(cacheKey))
            return CSVCache.Range[cacheKey]
        ocr := Trim(ocrTxt)
        if (ocr == "" || !FileExist(csvPath))
            return {found: false, min: "", max: ""}
        csvLines := StrSplit(FileRead(csvPath, "UTF-8"), Chr(10), Chr(13))
        for line in csvLines {
            parts := StrSplit(line, ",")
            if (parts.Length >= 3 && Trim(parts[1]) == ocr)
                return {found: true, min: Trim(parts[2]), max: Trim(parts[3])}
        }
        bestLen := 0, bestMin := "", bestMax := ""
        for line in csvLines {
            parts := StrSplit(line, ",")
            if (parts.Length < 3)
                continue
            key := Trim(parts[1])
            if (key == "")
                continue
            if (InStr(ocr, key) || (ocr != "" && InStr(key, ocr))) {
                if (StrLen(key) > bestLen) {
                    bestLen := StrLen(key)
                    bestMin := Trim(parts[2]), bestMax := Trim(parts[3])
                }
            }
        }
        result := {found: bestLen > 0, min: bestMin, max: bestMax}
        CSVCache.Range[cacheKey] := result
        return result
    }

    CSVCacheClear() {
        global CSVCache
		CSVCache.KeyValues := Map()
		CSVCache.Coords := Map()
		CSVCache.Range := Map()
		CSVCache.MultiMap := Map()
    }

    LoadCoordsCSV(path) {
        global CSVCache
        if (CSVCache.Coords.Has(path))
            return CSVCache.Coords[path]
        coords := []
        if (!FileExist(path))
            return coords
        for _, line in StrSplit(FileRead(path, "UTF-8"), Chr(10), Chr(13)) {
            parts := StrSplit(line, ",")
            if (parts.Length >= 2) {
                sx := Trim(parts[1]), sy := Trim(parts[2])
                if (IsNumber(sx) && IsNumber(sy))
                    coords.Push([Integer(sx), Integer(sy)])
            }
        }
        CSVCache.Coords[path] := coords
        return coords
    }

    LoadKeyValuesCSV(path) {
    global CSVCache
    if (CSVCache.KeyValues.Has(path))
        return CSVCache.KeyValues[path]
    result := Map()
    if (!FileExist(path))
        return result
    rawText := FileRead(path, "UTF-8")
    if (SubStr(rawText, 1, 1) == Chr(0xFEFF))
        rawText := SubStr(rawText, 2)
    for _, line in StrSplit(rawText, Chr(10), Chr(13)) {
        line := Trim(line)
        if (line == "")
            continue
        ; 优先逗号；整行无逗号时才退回制表符（避免混用 Tab+逗号导致错位）
        sep := InStr(line, ",") ? "," : (InStr(line, Chr(9)) ? Chr(9) : ",")
        parts := StrSplit(line, sep)
        if (parts.Length < 2)
            continue
        key := Trim(parts[1])
        vals := []
        Loop parts.Length - 1 {
            v := Trim(parts[A_Index + 1])
            if (v != "")
                vals.Push(v)
        }
        if (key != "" && !result.Has(key))
            result[key] := vals
    }
    CSVCache.KeyValues[path] := result
    return result
}

    ; 多坐标查表：按 key 命中后返回 [{x,y,value}, ...]，带 CSVCache 缓存
    LoadMultiMapCSV(path) {
        global CSVCache
        if (!CSVCache.Has("MultiMap"))
            CSVCache["MultiMap"] := Map()
        if (CSVCache["MultiMap"].Has(path))
            return CSVCache["MultiMap"][path]
        result := Map()
        if (!FileExist(path))
            return result
        rawText := FileRead(path, "UTF-8")
        if (SubStr(rawText, 1, 1) == Chr(0xFEFF))
            rawText := SubStr(rawText, 2)
        for _, line in StrSplit(rawText, Chr(10), Chr(13)) {
            line := Trim(line)
            if (line == "")
                continue
            sep := InStr(line, ",") ? "," : (InStr(line, Chr(9)) ? Chr(9) : ",")
            parts := StrSplit(line, sep)
            if (parts.Length < 4)
                continue
            key := Trim(parts[1])
            if (key == "" || result.Has(key))
                continue
            targets := []
            i := 2
            while (i + 2 <= parts.Length) {
                sx := Trim(parts[i]), sy := Trim(parts[i+1])
                tVal := Trim(parts[i+2])
                if (IsNumber(sx) && IsNumber(sy) && tVal != "")
                    targets.Push({x: Integer(sx), y: Integer(sy), value: tVal})
                i += 3
            }
            if (targets.Length > 0)
                result[key] := targets
        }
        CSVCache["MultiMap"][path] := result
        return result
    }

    SetTimer(RunStandaloneTasks, -100)

    RunStandaloneTasks() {
        global TaskArr, LoopLimit, IsPaused, IsStopped, VarPool, g_RetryCounter, OCR_Result, OCR_Keyword
        CSVCache.KeyValues := Map()
        CSVCache.Coords    := Map()
        CSVCache.Range     := Map()
        LogWrite("========== 独立脚本启动 (外层" LoopLimit "轮) ==========")
        OuterLoopIdx := 0
        Loop {
            OuterLoopIdx += 1
            if (LoopLimit > 0 && OuterLoopIdx > LoopLimit)
                break
            LogWrite("--- 第 " OuterLoopIdx " 轮 ---")
            for obj in TaskArr {
                if (obj.type == "点击坐标")
                    obj.exec_count := 0
                if (obj.type == "识别并填写")
                    obj.dbIndex := 1
            }
            IP := 1, LoopStack := [], IfStack := [], StepSafety := 0
            while (IP <= TaskArr.Length) {
                if (++StepSafety > 200000) {
                    MsgBox("执行步数过多，脚本强行终止！", "警告")
                    IsStopped := true
                    return
                }
                if (IsStopped)
                    return
                while (IsPaused) {
                    if (IsStopped)
                        return
                    Sleep(50)
                }
                obj := TaskArr[IP]
                LogWrite("STEP " IP " [" obj.type "]")

                if (obj.type == "🔁 局部循环开始") {
                    maxCount := 1
                    if (obj.HasOwnProp("loopSrc") && obj.loopSrc == "变量") {
                        varName := obj.HasOwnProp("varName") ? obj.varName : "LoopCount_OCR"
                        if (!VarPool.Has(varName)) {
                            act := HandleFail(IP, obj.type, "变量 " varName " 不存在")
                            if (act == "skip") {
                                IP += 1
                                continue
                            }
                            else if (act == "retry") {
                                SmartSleep(500)
                                continue
                            }
                            else {
                                return
                            }
                        }
                        val := VarPool[varName] + 0
                        if (val < 1) {
                            act := HandleFail(IP, obj.type, "变量 " varName "=" val " 无效(<1)")
                            if (act == "skip") {
                                IP += 1
                                continue
                            }
                            else if (act == "retry") {
                                SmartSleep(500)
                                continue
                            }
                            else {
                                return
                            }
                        }
                        maxCount := val
                    } else {
                        maxCount := obj.count
                    }
                    LoopStack.Push({startIP: IP, max: maxCount, current: 1})
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                    IP += 1
                    continue
                }
                if (obj.type == "🔚 局部循环结束") {
                    if (LoopStack.Length == 0) {
                        IP += 1
                        continue
                    }
                    top := LoopStack[LoopStack.Length]
                    top.current += 1
                    if (top.current <= top.max) {
                        IP := top.startIP + 1
                        continue
                    }
                    LoopStack.Pop()
                    IP += 1
                    continue
                }
                if (obj.type == "🔀 条件分支开始 (If)") {
                    condResult := false
                    if (obj.ifType == "颜色匹配") {
                        color := PixelGetColor(obj.x, obj.y, "RGB")
                        condResult := (StrUpper(SubStr(color, 3)) = StrUpper(obj.color))
                    } else if (obj.ifType == "变量匹配") {
                        matchVar := obj.HasOwnProp("matchVar") ? obj.matchVar : "CurrentLoop"
                        varVal := ""
                        if (matchVar == "CurrentLoop") {
                            varVal := (LoopStack.Length > 0) ? LoopStack[LoopStack.Length].current : OuterLoopIdx
                        } else {
                            varVal := VarPool.Has(matchVar) ? VarPool[matchVar] : ""
                        }
                        targetStr := Interpolate(obj.HasOwnProp("loopTarget") ? obj.loopTarget : "")
                        op := obj.HasOwnProp("loopOp") ? obj.loopOp : "=="
                        condResult := CompareValue(varVal, targetStr, op)
                    } else {
                        ocrTxt := OCR_Region(obj.ocrX, obj.ocrY, obj.ocrW, obj.ocrH)
                        OCR_Result := ocrTxt
                        OCR_Keyword := obj.keyword
                        condResult := InStr(ocrTxt, obj.keyword)
                    }
                    IfStack.Push({ifIP: IP, result: condResult})
                    if (!condResult) {
                        nest := 0, foundElse := false, searchIP := IP + 1
                        while (searchIP <= TaskArr.Length) {
                            tName := TaskArr[searchIP].type
                            if (tName == "🔀 条件分支开始 (If)") {
                                nest += 1
                            } else if (tName == "🔀 分支结束 (EndIf)") {
                                if (nest == 0) {
                                    IP := searchIP
                                    break
                                }
                                nest -= 1
                            } else if (tName == "🔀 否则 (Else)" && nest == 0) {
                                IP := searchIP + 1
                                foundElse := true
                                break
                            }
                            searchIP += 1
                        }
                        if (!foundElse && searchIP > TaskArr.Length) {
                            IP += 1
                            continue
                        }
                        continue
                    }
                    IP += 1
                    continue
                }
                if (obj.type == "🔀 否则 (Else)") {
                    nest := 0, searchIP := IP + 1
                    while (searchIP <= TaskArr.Length) {
                        tName := TaskArr[searchIP].type
                        if (tName == "🔀 条件分支开始 (If)") {
                            nest += 1
                        } else if (tName == "🔀 分支结束 (EndIf)") {
                            if (nest == 0) {
                                IP := searchIP
                                break
                            }
                            nest -= 1
                        }
                        searchIP += 1
                    }
                    if (IfStack.Length > 0)
                        IfStack.Pop()
                    IP += 1
                    continue
                }
                if (obj.type == "🔀 分支结束 (EndIf)") {
                    if (IfStack.Length > 0)
                        IfStack.Pop()
                    IP += 1
                    continue
                }

                if (obj.type == "激活窗口") {
                    waitSec := obj.HasOwnProp("winWait") ? obj.winWait : 0
                    success := false
                    if (waitSec > 0) {
                        if (WinWait(obj.winTitle, , waitSec)) {
                            if (WinActivate(obj.winTitle))
                                success := true
                        }
                    } else {
                        if (WinActivate(obj.winTitle))
                            success := true
                    }
                    if (!success) {
                        act := HandleFail(IP, obj.type, "激活失败: " obj.winTitle)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    SmartSleep(500)
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                else if (obj.type == "🚀 启动应用/快捷方式") {
                    targetPath := obj.path
                    if (!RegExMatch(targetPath, "^(?:[A-Za-z]:[\\/]|\\\\|[A-Za-z]+://)") && FileExist(A_ScriptDir "\" targetPath))
                        targetPath := A_ScriptDir "\" targetPath
                    isUrl := RegExMatch(targetPath, "^[A-Za-z]+://")
                    hasArgs := obj.HasOwnProp("args") && obj.args != ""
                    if (isUrl)
                        runTarget := targetPath
                    else if (hasArgs)
                        runTarget := Chr(34) . targetPath . Chr(34) . " " . obj.args
                    else
                        runTarget := targetPath
                    try {
                        Run(runTarget)
                    } catch Error as e {
                        act := HandleFail(IP, obj.type, "启动失败: " e.Message)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    if (obj.HasOwnProp("winTitle") && obj.winTitle != "") {
                        if (WinWait(obj.winTitle, , 15)) {
                            try WinActivate(obj.winTitle)
                        }
                    } else {
                        SmartSleep(obj.HasOwnProp("waitMs") ? obj.waitMs : 1500)
                    }
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                else if (obj.type == "点击坐标") {
                    realX := obj.x + (obj.offsetX * obj.exec_count)
                    realY := obj.y + (obj.offsetY * obj.exec_count)
                    MouseMove(realX, realY, 0), SmartSleep(150)
                    if (IsStopped)
                        return
                    clicks := obj.HasOwnProp("clickCount") ? obj.clickCount : 1
                    Loop clicks {
                        Click()
                        if (A_Index < clicks)
                            SmartSleep(50)
                    }
                    if (obj.HasOwnProp("text") && (obj.text != "" || obj.pasteClip)) {
                        SmartSleep(150)
                        if (obj.replace) {
                            Send("^a")
                            SmartSleep(100)
                        }
                        if (obj.pasteClip) {
                            Send("^v")
                        } else {
                            SendText(Interpolate(obj.text))
                        }
                    }
                    SmartSleep(500)
                    obj.exec_count += 1
                }
                else if (obj.type == "发送按键") {
                    Send(obj.key), SmartSleep(300)
                }
                else if (obj.type == "延时等待") {
                    SmartSleep(Integer(obj.ms))
                }
                else if (obj.type == "截图找图") {
                    simv := obj.HasOwnProp("sim") ? obj.sim : 70
                    imgWait := obj.HasOwnProp("imgWait") ? obj.imgWait : 0
                    found := false, fx := 0, fy := 0
                    if (imgWait > 0) {
                        startT := A_TickCount
                        while (A_TickCount - startT < imgWait * 1000) {
                            if (ImageSearch(&fx, &fy, 0, 0, A_ScreenWidth, A_ScreenHeight, "*" simv " " obj.path)) {
                                found := true
                                break
                            }
                            if (IsStopped)
                                return
                            Sleep(300)
                        }
                    } else {
                        found := ImageSearch(&fx, &fy, 0, 0, A_ScreenWidth, A_ScreenHeight, "*" simv " " obj.path)
                    }
                    if (!found) {
                        errMsg := (imgWait > 0) ? ("等" imgWait "s后仍找不到图片") : "找不到图片"
                        act := HandleFail(IP, obj.type, errMsg "：" obj.path)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    action := obj.HasOwnProp("imgAction") ? obj.imgAction : "点击图片中心"
                    offX := obj.HasOwnProp("imgOffX") ? obj.imgOffX : 0
                    offY := obj.HasOwnProp("imgOffY") ? obj.imgOffY : 0
                    clickX := fx + offX, clickY := fy + offY
                    if (action == "点击图片中心") {
                        sz := GetImageSize(obj.path)
                        if (sz[1] > 0 && sz[2] > 0) {
                            clickX := fx + (sz[1] // 2) + offX
                            clickY := fy + (sz[2] // 2) + offY
                        }
                    }
                    MouseMove(clickX, clickY, 0), SmartSleep(150)
                    if (IsStopped)
                        return
                    if (action != "仅移动不点击")
                        Click()
                    SmartSleep(500)
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                else if (obj.type == "识别并填写") {
                    ocrTxt := OCR_Region(obj.ocrX, obj.ocrY, obj.ocrW, obj.ocrH)
                    OCR_Result := ocrTxt
                    if (Trim(ocrTxt) == "") {
                        act := HandleFail(IP, obj.type, "OCR 未识别到任何内容")
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    extractNum := obj.HasOwnProp("extractNum") ? obj.extractNum : true
                    numTxt := ocrTxt
                    if (extractNum) {
                        if (obj.HasOwnProp("keepDot") && obj.keepDot)
                            numTxt := RegExReplace(ocrTxt, "[^0-9\.-]", "")
                        else
                            numTxt := RegExReplace(ocrTxt, "[^0-9-]", "")
                        if (numTxt == "") {
                            act := HandleFail(IP, obj.type, "提取数字后为空（原文：[" ocrTxt "]）")
                            if (act == "skip") {
                                IP += 1
                                continue
                            }
                            else if (act == "retry") {
                                SmartSleep(800)
                                continue
                            }
                            else {
                                return
                            }
                        }
                    }
                    if (obj.HasOwnProp("saveToVar") && obj.saveToVar) {
    varName := obj.HasOwnProp("saveVarName") && obj.saveVarName != "" ? obj.saveVarName : "LoopCount_OCR"
    finalVal := numTxt
    if (RegExMatch(finalVal, "^-?\d+(?:\.\d+)?$")) {
        if (obj.HasOwnProp("mathOp") && Trim(obj.mathOp) != "") {
            mOp := Trim(obj.mathOp)
            op := SubStr(mOp, 1, 1), valStr := Trim(SubStr(mOp, 2))
            if (RegExMatch(op, "^[+\-*/]$") && RegExMatch(valStr, "^-?\d+(?:\.\d+)?$")) {
                n := finalVal + 0
                switch op {
                    case "+": n += valStr + 0
                    case "-": n -= valStr + 0
                    case "*": n *= valStr + 0
                    case "/": n := (valStr + 0 != 0) ? n / (valStr + 0) : n
                }
                finalVal := n
            }
        }
        if (obj.HasOwnProp("round1") && obj.round1)
            finalVal := Round(finalVal + 0, 1)
    }
    if (RegExMatch(finalVal, "^-?\d+(\.\d+)?$"))
        VarPool[varName] := finalVal + 0
    else
        VarPool[varName] := finalVal
    ToolTip("已存入 " varName ": " VarPool[varName], 10, 10), SmartSleep(800)
    LogWrite("  ↳ 变量 " varName " = " VarPool[varName])
    if (g_RetryCounter.Has(IP))
        g_RetryCounter.Delete(IP)
    IP += 1
    continue
}
                    fillValues := []
                    if (obj.HasOwnProp("useDB") && obj.useDB && obj.HasOwnProp("dbPath") && FileExist(obj.dbPath)) {
                        kvMap := LoadKeyValuesCSV(obj.dbPath)
                        if (kvMap.Has(Trim(numTxt)))
                            fillValues := kvMap[Trim(numTxt)]
                    }
                    if (fillValues.Length == 0)
                        fillValues.Push(numTxt)
                    for idx, rawVal in fillValues {
                        if (rawVal != "" && RegExMatch(rawVal, "^-?\d+(?:\.\d+)?$")) {
                            v := rawVal
                            if (obj.HasOwnProp("mathOp") && Trim(obj.mathOp) != "") {
    mOp := Trim(obj.mathOp)
    op := SubStr(mOp, 1, 1), valStr := Trim(SubStr(mOp, 2))
                                if (RegExMatch(op, "^[+\-*/]$") && RegExMatch(valStr, "^-?\d+(?:\.\d+)?$")) {
                                    n := v + 0
                                    switch op {
                                        case "+": n += valStr + 0
                                        case "-": n -= valStr + 0
                                        case "*": n *= valStr + 0
                                        case "/": n := (valStr + 0 != 0) ? n / (valStr + 0) : n
                                    }
                                    v := n
                                }
                            }
                            if (extractNum && obj.HasOwnProp("round1") && obj.round1)
                                v := Round(v + 0, 1)
                            fillValues[idx] := v
                        }
                    }
                    targets := []
                    if (obj.HasOwnProp("fillX") && (obj.fillX != 0 || obj.fillY != 0))
                        targets.Push({x: obj.fillX, y: obj.fillY})
                    if (obj.HasOwnProp("fillX2") && (obj.fillX2 != 0 || obj.fillY2 != 0))
                        targets.Push({x: obj.fillX2, y: obj.fillY2})
                    if (obj.HasOwnProp("fillX3") && (obj.fillX3 != 0 || obj.fillY3 != 0))
                        targets.Push({x: obj.fillX3, y: obj.fillY3})
                    if (obj.onlyClip) {
                        clipVal := (fillValues.Length > 0) ? fillValues[1] : ""
                        if (clipVal == "") {
                            act := HandleFail(IP, obj.type, "无内容可存入剪贴板")
                            if (act == "skip") {
                                IP += 1
                                continue
                            }
                            else if (act == "retry") {
                                SmartSleep(800)
                                continue
                            }
                            else {
                                return
                            }
                        }
                        A_Clipboard := clipVal
                        try ClipWait(1)
                        ToolTip("已存入剪贴板: " clipVal, 10, 10), SmartSleep(500)
                    } else if (targets.Length == 1) {
                        if (!obj.HasOwnProp("dbIndex"))
                            obj.dbIndex := 1
                        if (obj.dbIndex < 1 || obj.dbIndex > fillValues.Length)
                            obj.dbIndex := 1
                        pasteVal := fillValues[obj.dbIndex]
                        obj.dbIndex += 1
                        MouseMove(targets[1].x, targets[1].y, 0), SmartSleep(150)
                        if (IsStopped)
                            return
                        Click(), SmartSleep(150)
                        Send("^a")
                        SmartSleep(100)
                        if (obj.HasOwnProp("sendText") && obj.sendText && RegExMatch(pasteVal, "^[\x20-\x7E]+$"))
                            SendText(pasteVal)
                        else
                            FillValue(pasteVal)
                        SmartSleep(300)
                    } else if (targets.Length > 1) {
                        pasteCount := Min(fillValues.Length, targets.Length)
                        Loop pasteCount {
                            pasteVal := fillValues[A_Index]
                            MouseMove(targets[A_Index].x, targets[A_Index].y, 0), SmartSleep(150)
                            if (IsStopped)
                                return
                            Click(), SmartSleep(150)
                            Send("^a")
                            SmartSleep(100)
                            if (obj.HasOwnProp("sendText") && obj.sendText && RegExMatch(pasteVal, "^[\x20-\x7E]+$"))
                                SendText(pasteVal)
                            else
                                FillValue(pasteVal)
                            SmartSleep(300)
                        }
                    }
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                else if (obj.type == "🎲 范围随机填写") {
                    ocrTxt := OCR_Region(obj.ocrX, obj.ocrY, obj.ocrW, obj.ocrH)
                    OCR_Result := ocrTxt
                    if (Trim(ocrTxt) == "") {
                        act := HandleFail(IP, obj.type, "OCR 未识别到内容，无法查范围表")
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    res := FindRangeByKey(obj.dbPath, ocrTxt)
                    if (!res.found) {
                        act := HandleFail(IP, obj.type, "查表失败，OCR原文: 「" ocrTxt "」")
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    coordList := LoadCoordsCSV(obj.posDBPath)
                    if (coordList.Length == 0) {
                        act := HandleFail(IP, obj.type, "坐标表无有效行")
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    minNum := res.min + 0, maxNum := res.max + 0
                    decimals := obj.decimals
                    divisor := 10 ** decimals
                    
                    usedVals := Map()
                    
                    for _, c in coordList {
                        attempts := 0
                        while (true) {
                            if (obj.HasOwnProp("onlyEven") && obj.onlyEven) {
                                minInt := Round(minNum * divisor), maxInt := Round(maxNum * divisor)
                                minEven := Ceil(minInt / 2), maxEven := Floor(maxInt / 2)
                                if (minEven > maxEven) {
                                    randText := Format("{:." . decimals . "f}", minNum)
                                } else {
                                    randInt := Random(minEven, maxEven) * 2
                                    randText := Format("{:." . decimals . "f}", randInt / divisor)
                                }
                            } else if (decimals == 0) {
                                randText := String(Random(Integer(minNum), Integer(maxNum)))
                            } else {
                                randInt := Random(Round(minNum * divisor), Round(maxNum * divisor))
                                randText := Format("{:." . decimals . "f}", randInt / divisor)
                            }
                            
                            attempts += 1
                            totalPossible := (maxNum - minNum) * divisor + 1
                            if (!usedVals.Has(randText) || attempts > 100 || usedVals.Count >= totalPossible)
                                break
                        }
                        usedVals[randText] := true
                        
                        MouseMove(c[1], c[2], 0), SmartSleep(150)
                        if (IsStopped)
                            return
                        Click(), SmartSleep(150)
                        Send("^a")
                        SmartSleep(100)
                        FillValue(randText)
                        SmartSleep(300)
                    }
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                else if (obj.type == "📊 坐标查表填写") {
                    if (OCR_Result == "") {
                        act := HandleFail(IP, obj.type, "上一步 OCR 结果为空")
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    if (!FileExist(obj.dbPath)) {
                        act := HandleFail(IP, obj.type, "数据 CSV 不存在: " obj.dbPath)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else {
                            return
                        }
                    }
                    lookupKey := (obj.HasOwnProp("matchType") && obj.matchType == "用包含文字匹配") ? OCR_Keyword : OCR_Result
                    multiMap := LoadMultiMapCSV(obj.dbPath)
                    if (!multiMap.Has(lookupKey)) {
                        ToolTip("⚠️ 查表失败：找不到 [" lookupKey "]，跳过", 10, 10)
                        Sleep(1500)
                        LogWrite("  ⚠️ 关键词 [" lookupKey "] 不存在，跳过")
                    } else {
                        for _, tgt in multiMap[lookupKey] {
                            MouseMove(tgt.x, tgt.y, 0), SmartSleep(150)
                            if (IsStopped)
                                return
                            Click(), SmartSleep(150)
                            Send("^a")
                            SmartSleep(100)
                            FillValue(tgt.value)
                            SmartSleep(300)
                        }
                    }
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                else if (obj.type == "🕹️ 条件跳过") {
                    isMatched := false
                    if (obj.HasOwnProp("skipBasis") && obj.skipBasis == "OCR文字") {
                        ocrTxt := OCR_Region(obj.ocrX, obj.ocrY, obj.ocrW, obj.ocrH)
                        OCR_Result := ocrTxt
                        OCR_Keyword := obj.keyword
                        isMatched := InStr(ocrTxt, obj.keyword) ? true : false
                    } else if (obj.HasOwnProp("skipBasis") && obj.skipBasis == "变量匹配") {
                        matchVar := obj.HasOwnProp("matchVar") ? obj.matchVar : "CurrentLoop"
                        varVal := ""
                        if (matchVar == "CurrentLoop") {
                            varVal := (LoopStack.Length > 0) ? LoopStack[LoopStack.Length].current : OuterLoopIdx
                        } else {
                            varVal := VarPool.Has(matchVar) ? VarPool[matchVar] : ""
                        }
                        targetStr := Interpolate(obj.HasOwnProp("loopTarget") ? obj.loopTarget : "")
                        op := obj.HasOwnProp("loopOp") ? obj.loopOp : "=="
                        isMatched := CompareValue(varVal, targetStr, op)
                    } else {
                        color := PixelGetColor(obj.x, obj.y, "RGB")
                        isMatched := (StrUpper(SubStr(color, 3)) = StrUpper(obj.color))
                    }
                    skipAction := obj.HasOwnProp("skipAction") ? obj.skipAction : "匹配 → 跳过N步"
                    skipN := obj.HasOwnProp("skipN") ? obj.skipN : 1
                    if (skipAction == "匹配 → 彻底停止") {
                        if (isMatched) {
                            IsStopped := true
                            ToolTip("⏹ 条件匹配，任务已停止", 10, 10), Sleep(1500)
                            return
                        }
                    } else if (skipAction == "匹配 → 跳过N步") {
                        if (isMatched) {
                            IP := SkipSteps(IP, skipN)
                            continue
                        }
                    } else {
                        if (!isMatched) {
                            IP := SkipSteps(IP, skipN)
                            continue
                        }
                    }
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                else if (obj.type == "📝 设置变量") {
                    varName := obj.varName
                    if (!RegExMatch(varName, "^[A-Za-z_]\w*$")) {
                        act := HandleFail(IP, obj.type, "变量名非法: " varName)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else {
                            return
                        }
                    }
                    finalVal := Interpolate(obj.varValue)
                    if (RegExMatch(finalVal, "^-?\d+(\.\d+)?$"))
                        VarPool[varName] := finalVal + 0
                    else
                        VarPool[varName] := finalVal
                    ToolTip("📝 " varName " = " VarPool[varName], 10, 10), SmartSleep(600)
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
; =============== 🔍 OCR识别保存文本 ===============
else if (obj.type == "🔍 OCR识别保存文本") {
    __items := OCR_RegionDetailed(obj.ocrX, obj.ocrY, obj.ocrW, obj.ocrH)
    if (__items.Length == 0) {
        act := HandleFail(IP, obj.type, "OCR 无识别结果")
        if (act == "skip") {
            IP += 1
            continue
        }
        else if (act == "retry") {
            SmartSleep(800)
            continue
        }
        else return
    }

    texts := []
    Loop __items.Length {
        texts.Push(__items[A_Index].text)
    }

    mode := obj.extractMode
    filterRe := obj.filterRegex
    delimStr := Chr(10)
    if (obj.delimiter == "逗号")
        delimStr := ","
    else if (obj.delimiter == "空格")
        delimStr := " "
    else if (obj.delimiter == "制表符")
        delimStr := Chr(9)

    finalText := ""
    count := 0

    if (mode == "全部文本") {
        filtered := []
        Loop texts.Length {
            t := texts[A_Index]
            if (filterRe == "" || RegExMatch(t, filterRe))
                filtered.Push(t)
        }
        count := filtered.Length
        Loop filtered.Length {
            if (A_Index > 1)
                finalText .= delimStr
            finalText .= filtered[A_Index]
        }
    } else if (mode == "第N项") {
        n := obj.extractN
        if (n >= 1 && n <= texts.Length) {
            finalText := texts[n]
            count := 1
        }
    } else if (mode == "首个匹配正则") {
        Loop texts.Length {
            if (RegExMatch(texts[A_Index], filterRe, &mm)) {
                finalText := mm[0]
                count := 1
                break
            }
        }
    } else if (mode == "全部匹配正则") {
        allMatches := []
        Loop texts.Length {
            p := 1
            src := texts[A_Index]
            while (p <= StrLen(src)) {
                if (!RegExMatch(SubStr(src, p), filterRe, &mm))
                    break
                allMatches.Push(mm[0])
                p += mm.Pos - 1 + mm.Len
                if (mm.Len == 0)
                    p += 1
            }
        }
        count := allMatches.Length
        Loop allMatches.Length {
            if (A_Index > 1)
                finalText .= delimStr
            finalText .= allMatches[A_Index]
        }
    }

    if (finalText == "") {
        act := HandleFail(IP, obj.type, "提取结果为空（识别 " . texts.Length . " 项）")
        if (act == "skip") {
            IP += 1
            continue
        }
        else if (act == "retry") {
            SmartSleep(800)
            continue
        }
        else return
    }

    saveVarName := obj.saveVar == "" ? "OCRText" : obj.saveVar
    VarPool[saveVarName] := finalText
    VarPool[saveVarName . "_Count"] := count

    preview := finalText
    if (StrLen(preview) > 40)
        preview := SubStr(preview, 1, 40) . "..."
    ToolTip("🔍 " . saveVarName . " = " . preview, 10, 10)
    LogWrite("  ↳ 识别保存 " . saveVarName . " (count=" . count . ")")
    SmartSleep(600)
    if (g_RetryCounter.Has(IP))
        g_RetryCounter.Delete(IP)
}
; =============== 🎯 匹配文本并点击 ===============
else if (obj.type == "🎯 匹配文本并点击") {
    kw := Interpolate(obj.keyword)
    mode := obj.matchMode
    strategy := obj.matchStrategy
    matchN := obj.HasOwnProp("matchN") ? obj.matchN : 1
    findWait := obj.findWait
    deadline := A_TickCount + findWait * 1000

    matches := []
    Loop {
        __items := OCR_RegionDetailed(obj.ocrX, obj.ocrY, obj.ocrW, obj.ocrH)
        matches := []
        Loop __items.Length {
            item := __items[A_Index]
            hit := false
            if (mode == "完全等于") {
                hit := (item.text == kw)
            } else if (mode == "正则") {
                try {
                    hit := RegExMatch(item.text, kw) ? true : false
                } catch {
                    hit := false
                }
            } else {
                hit := InStr(item.text, kw) ? true : false
            }
            if (hit)
                matches.Push(item)
        }
        if (matches.Length > 0)
            break
        if (findWait == 0 || A_TickCount >= deadline)
            break
        if (IsStopped)
            return
        SmartSleep(300)
    }

    if (matches.Length == 0) {
        act := HandleFail(IP, obj.type, "找不到关键词 [" . kw . "]")
        if (act == "skip") {
            IP += 1
            continue
        }
        else if (act == "retry") {
            SmartSleep(800)
            continue
        }
        else return
    }

    posMode := obj.clickPos
    offX := obj.clickOffX
    offY := obj.clickOffY
    clickAct := obj.clickAction

    if (strategy == "全部") {
        Loop matches.Length {
            item := matches[A_Index]
            cx := item.cx
            cy := item.cy
            if (posMode == "左上角") {
                cx := item.x
                cy := item.y
            } else if (posMode == "右下角") {
                cx := item.x + item.w
                cy := item.y + item.h
            } else if (posMode == "右侧中点") {
                cx := item.x + item.w + 5
                cy := item.cy
            }
            cx += offX
            cy += offY
            LogWrite("  🎯 点击 [" . item.text . "] @ " . cx . "," . cy)
            MouseMove(cx, cy, 0)
            SmartSleep(150)
            if (IsStopped)
                return
            if (clickAct != "仅移动不点击")
                Click()
            SmartSleep(400)
        }
    } else {
        idx := 1
        if (strategy == "第N个")
            idx := matchN
        if (idx < 1 || idx > matches.Length)
            idx := 1
        item := matches[idx]
        cx := item.cx
        cy := item.cy
        if (posMode == "左上角") {
            cx := item.x
            cy := item.y
        } else if (posMode == "右下角") {
            cx := item.x + item.w
            cy := item.y + item.h
        } else if (posMode == "右侧中点") {
            cx := item.x + item.w + 5
            cy := item.cy
        }
        cx += offX
        cy += offY
        LogWrite("  🎯 点击 [" . item.text . "] @ " . cx . "," . cy)
        MouseMove(cx, cy, 0)
        SmartSleep(150)
        if (IsStopped)
            return
        if (clickAct != "仅移动不点击")
            Click()
        SmartSleep(400)
    }
    if (g_RetryCounter.Has(IP))
        g_RetryCounter.Delete(IP)
}
                else if (obj.type == "📦 调用子脚本") {
                    scriptPath := Interpolate(obj.scriptPath)
                    if (!FileExist(scriptPath)) {
                        act := HandleFail(IP, obj.type, "子脚本不存在: " scriptPath)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else return
                    }
                    resultFile := obj.HasOwnProp("resultFile") ? Interpolate(obj.resultFile) : ""
                    if (resultFile == "")
                        resultFile := A_Temp . "\subresult_" . A_TickCount . ".ini"
                    try FileDelete(resultFile)
                    argsStr := Interpolate(obj.HasOwnProp("args") ? obj.args : "")
                    
                    if (SubStr(StrLower(scriptPath), -3) == ".exe") {
                        cmd := Chr(34) . scriptPath . Chr(34)
                    } else {
                        cmd := Chr(34) . A_AhkPath . Chr(34) . " " . Chr(34) . scriptPath . Chr(34)
                    }
                    if (argsStr != "")
                        cmd .= " " . argsStr
                    cmd .= " " . Chr(34) . resultFile . Chr(34)
                    try {
                        pid := Run(cmd)
                    } catch Error as e {
                        act := HandleFail(IP, obj.type, "启动失败: " e.Message)
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else return
                    }
                    waitMode := obj.HasOwnProp("waitMode") ? obj.waitMode : "阻塞"
                    if (waitMode == "不等待") {
                        IP += 1
                        continue
                    }
                    startT := A_TickCount
                    timeout := obj.HasOwnProp("timeout") ? obj.timeout : 0
                    killed := false
                    while (ProcessExist(pid)) {
                        if (IsStopped) {
                            try ProcessClose(pid)
                            return
                        }
                        if (timeout > 0 && (A_TickCount - startT) > timeout * 1000) {
                            try ProcessClose(pid)
                            killed := true
                            break
                        }
                        SmartSleep(200)
                    }
                    if (killed) {
                        act := HandleFail(IP, obj.type, "子脚本超时(" timeout "s)，已强制结束")
                        if (act == "skip") {
                            IP += 1
                            continue
                        }
                        else if (act == "retry") {
                            SmartSleep(800)
                            continue
                        }
                        else return
                    }
                    Sleep(100)
                    if (FileExist(resultFile)) {
                        status := IniRead(resultFile, "result", "status", "")
                        value := IniRead(resultFile, "result", "value", "")
                        if (status == "ok") {
                            if (obj.HasOwnProp("resultVarName") && obj.resultVarName != "")
                                VarPool[obj.resultVarName] := value
                        } else if (status == "fail") {
                            msg := IniRead(resultFile, "result", "message", "")
                            act := HandleFail(IP, obj.type, "子脚本报告失败: " msg)
                            try FileDelete(resultFile)
                            if (act == "skip") {
                                IP += 1
                                continue
                            }
                            else if (act == "retry") {
                                SmartSleep(800)
                                continue
                            }
                            else return
                        }
                        try FileDelete(resultFile)
                    }
                    if (g_RetryCounter.Has(IP))
                        g_RetryCounter.Delete(IP)
                }
                
                IP += 1
            }
        }
        if (!IsStopped) {
            MsgBox("✅ 所有任务执行完毕！")
        }
        ExitApp()
    }
    )'

    engineCode := StrReplace(engineCode, "{{__LOOPLIMIT__}}", loopLimitVal)
    engineCode := StrReplace(engineCode, "{{__TASKSCODE__}}", tasksCode)
    engineCode := StrReplace(engineCode, "{{__FAILPOLICY__}}", FailPolicy)
    engineCode := StrReplace(engineCode, "{{__LOGENABLED__}}", logBool)
    engineCode := StrReplace(engineCode, "{{__LOGPATH__}}", logPathSafe)

    try {
        FileAppend(engineCode, file, "UTF-8")
        MsgBox("✅ 已导出：`n" file "`n`n失败策略: " FailPolicy "`n日志: " (LogEnabled ? "开 → " LogPath : "关"), "成功", "Iconi")
    } catch Error as e {
        MsgBox("导出失败: " . e.Message)
    }
}