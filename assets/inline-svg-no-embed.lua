-- inline-svg-no-embed.lua

local function has_class(el, class)
  for _, c in ipairs(el.classes) do
    if c == class then return true end
  end
  return false
end

local function dirname(path)
  return path:match("^(.*)[/\\][^/\\]*$") or "."
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*all")
  f:close()
  return content
end

local function resolve_svg_path(src)
  local candidates = { src }

  if PANDOC_STATE and PANDOC_STATE.input_files and #PANDOC_STATE.input_files > 0 then
    table.insert(candidates, dirname(PANDOC_STATE.input_files[1]) .. "/" .. src)
  end

  if PANDOC_STATE and PANDOC_STATE.resource_path then
    for _, p in ipairs(PANDOC_STATE.resource_path) do
      table.insert(candidates, p .. "/" .. src)
    end
  end

  for _, p in ipairs(candidates) do
    local content = read_file(p)
    if content then return content end
  end

  return nil
end

local function clean_svg(svg)
  svg = svg:gsub("^%s*<%?xml.-%?>%s*", "")
  svg = svg:gsub("^%s*<!DOCTYPE.->%s*", "")
  return svg
end

function Para(el)
  if #el.content ~= 1 or el.content[1].t ~= "Image" then
    return nil
  end

  local img = el.content[1]

  if not img.src:lower():match("%.svg$") then
    return nil
  end

  if not has_class(img, "searchable-svg") then
    return nil
  end

  local svg = resolve_svg_path(img.src)
  if not svg then
    io.stderr:write("Could not inline SVG: " .. img.src .. "\n")
    return nil
  end

  svg = clean_svg(svg)

  local width = img.attributes["width"] or "100%"
  local align = img.attributes["fig-align"] or "left"

  local style = "width:" .. width .. ";"
  if align == "center" then
    style = style .. " margin-left:auto; margin-right:auto;"
  end

  return pandoc.RawBlock(
    "html",
    '<div class="searchable-svg" style="' .. style .. '">\n' .. svg .. '\n</div>'
  )
end