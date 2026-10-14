local InkWidgetHelper = {}

-- === Core Creation Functions ===

function InkWidgetHelper.createText(name, text, fontSize, color, parent, scaleFactor, userSettings)
    --str, str, int, str, widgetRef, float
    scaleFactor = scaleFactor or 1.0
    local widget = inkText.new()
    widget:SetVisible(false)
    widget:SetName(name); CName.add(name)
    widget:SetStyle(ResRef.FromName("base\\gameplay\\gui\\common\\main_colors.inkstyle"))
    widget:SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily")
    widget:BindProperty("tintColor", color)
    widget:SetFontStyle("Bold")
    widget:SetLetterCase("OriginalCase")
    widget:SetFontSize(math.floor(fontSize * scaleFactor))
    widget:SetText(text)
    widget:SetHorizontalAlignment(textHorizontalAlignment.Center)
    widget:SetAnchor(inkEAnchor.TopFillHorizontaly)
    widget:SetMargin(0, 3, 0, 0)
    widget:EnableAutoScroll(true)
    widget:SetScrollTextSpeed(0.5)
    if parent then widget:Reparent(parent) end
    return widget
end

function InkWidgetHelper.createRectangle(name, size, color, opacity, parent, scaleFactor)
    --str, table with 2 int values, str, float, widgetRef, float
    scaleFactor = scaleFactor or 1.0
    local rect = inkRectangle.new()
    rect:SetName(name); CName.add(name)
    rect:SetStyle(ResRef.FromName("base\\gameplay\\gui\\common\\main_colors.inkstyle"))
    rect:BindProperty("tintColor", color)
    rect:SetOpacity(opacity or 1.0)
    rect:SetSize(size[1]*scaleFactor, size[2]*scaleFactor)
    rect:SetVisible(false)
    if parent then rect:Reparent(parent) end
    return rect
end

-- Creates a canvas widget to act as a container for other widgets
function InkWidgetHelper.createCanvas(name, parent)
    local canvas = inkCanvas.new()
    canvas:SetName(name); CName.add(name)
    canvas:SetVisible(false)
    if parent then canvas:Reparent(parent) end
    return canvas
end


-- === Alert Widget Functions (Displays an alert message in-game, centered at the top of the screen) ===

-- Creates the background widget and the main text container (inkCanvas).
function InkWidgetHelper.createAlertWidgets(parent, PADDING, ALERT_HEIGHT, userSettings)
    --widgetRef, int, int
    local alertWidgets = {
        background = InkWidgetHelper.createRectangle("InkWidgetHelper_Background", {0, ALERT_HEIGHT}, "MainColors.Red", 0.3, parent, 1.0),
        textContainer = InkWidgetHelper.createCanvas("InkWidgetHelper_TextContainer", parent),
        textLines = {}
    }

    alertWidgets.textContainer:SetAnchor(inkEAnchor.TopFillHorizontaly)
    alertWidgets.textContainer:SetHAlign(inkEHorizontalAlign.Center)
    alertWidgets.textContainer:SetFitToContent(false)
    alertWidgets.textContainer:SetMargin(0, 3, 0, 0)

    alertWidgets.background:SetAnchor(inkEAnchor.TopFillHorizontaly)
    alertWidgets.background:SetMargin(0, 0, 0, 0)
    
    return alertWidgets
end

-- Deletes all dynamic text line widgets and clears the array
local function clearTextLines(alertWidgets)
    if alertWidgets.textLines then
        for _, textWidget in ipairs(alertWidgets.textLines) do
            -- Instead of destroying, just set invisible for now, as deletion is often not supported
            -- in this environment and setting visibility to false is safer.
            textWidget:SetVisible(false) 
        end
        alertWidgets.textLines = {}
    end
end

-- New function to just update existing text, used for single-line updates like the date/time
function InkWidgetHelper.updateSingleLineText(alertWidgets, text, userSettings)
    if not alertWidgets.textLines or #alertWidgets.textLines == 0 then
        -- Widgets don't exist yet, defer to the full creation function
        return false 
    end
    
    local textWidget = alertWidgets.textLines[1]
    if textWidget then
        -- The date/time display is always a single line, so we only need to update the first widget.
        textWidget:SetText(text)
        InkWidgetHelper.setVisibility(alertWidgets, true, userSettings)
        return true
    end
    return false
end

function InkWidgetHelper.setAlertWidgetProperties(alertWidgets, text, vSize, gameRes, PADDING, userSettings)
    --table, str, int, table of 2 ints, int

    if not alertWidgets.textContainer or not text then return end

    -- Split the text into lines
    local lines = {}
    for line in string.gmatch(text, "[^\r\n]+") do
        table.insert(lines, line)
    end
    local lineCount = #lines

    -- Check if the number of lines has changed (or if this is the first run)
    if lineCount ~= #alertWidgets.textLines or lineCount == 0 then
        -- Clear existing widgets if the line count doesn't match the required count
        clearTextLines(alertWidgets)

        local scaleFactor = gameRes.X / 1920.0
        local scaledVSize = math.floor(vSize * scaleFactor)
        local lineHeight = (scaledVSize + math.floor(4 * scaleFactor)) * 1.2
        local textHeight = math.floor(lineCount * lineHeight)
        local boxHeight = math.floor(textHeight * 1.15)
        local totalHeight = boxHeight
        local totalWidth = gameRes.X

        alertWidgets.background:SetSize(totalWidth, totalHeight)

        local verticalStartOffset = (totalHeight - textHeight) / 2
        local currentY = verticalStartOffset
        
        for i, lineText in ipairs(lines) do
            -- RE-CREATE text widgets
            local lineWidget = InkWidgetHelper.createText("InkWidgetHelper_TextLine" .. i, lineText, vSize, "MainColors.Blue", alertWidgets.textContainer, 1.0, userSettings)
            lineWidget:SetMargin(0, currentY, 0, 0)
            lineWidget:SetSize(gameRes.X, lineHeight)
            table.insert(alertWidgets.textLines, lineWidget)
            currentY = currentY + lineHeight
        end

        alertWidgets.textContainer:SetSize(totalWidth, totalHeight)

    else
        -- Line count matches: Just update the text of the existing widgets
        for i, lineText in ipairs(lines) do
            local lineWidget = alertWidgets.textLines[i]
            if lineWidget then
                lineWidget:SetText(lineText)
            end
        end
    end

    InkWidgetHelper.setVisibility(alertWidgets, true, userSettings)
end

-- === Extra Utility Functions ===

function InkWidgetHelper.setText(widget, fmt, val)
    if widget then widget:SetText(string.format(fmt, val)) end
end

function InkWidgetHelper.setVisibility(widgets, visible, userSettings)
    if userSettings.includeBg then
        if widgets.background then widgets.background:SetVisible(visible) end
    else
        if widgets.background then widgets.background:SetVisible(false) end
    end
    if widgets.textContainer then widgets.textContainer:SetVisible(visible) end
    if widgets.textLines then
        for _, w in ipairs(widgets.textLines) do
            if w then w:SetVisible(visible) end
        end
    end
end

return InkWidgetHelper
