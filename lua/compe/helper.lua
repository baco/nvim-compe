local Pattern = require'compe.pattern'
local Character = require'compe.utils.character'

local Helper = {}

--- determine
Helper.determine = function(context, option)
  local trigger_character_offset = 0
  if option and option.trigger_characters and context.before_char ~= ' ' then
    if vim.tbl_contains(option.trigger_characters, context.before_char) then
      trigger_character_offset = context.col
    end
  end

  local keyword_pattern_offset
  if option and option.keyword_pattern then
    keyword_pattern_offset = Pattern.get_pattern_offset(context.before_line, option.keyword_pattern)
  end

  return {
    keyword_pattern_offset = keyword_pattern_offset or Pattern.get_keyword_offset(context);
    trigger_character_offset = trigger_character_offset;
  }
end

--- get_keyword_pattern
Helper.get_keyword_pattern = function(filetype)
  return Pattern.get_keyword_pattern(filetype)
end

--- get_default_keyword_pattern
Helper.get_default_pattern = function()
  return Pattern.get_default_pattern()
end

--- convert_lsp
Helper.convert_lsp = function(args)
  local keyword_pattern_offset = args.keyword_pattern_offset
  local context = args.context
  local request = args.request
  local response = args.response

  local complete_items = {}
  for _, completion_item in pairs(vim.tbl_islist(response or {}) and response or response.items or {}) do
    local word = ''
    local abbr = ''
    if completion_item.insertTextFormat == 2 then
      word = completion_item.label
      abbr = completion_item.label

      local text = word
      if completion_item.textEdit ~= nil then
        text = completion_item.textEdit.newText or text
      elseif completion_item.insertText ~= nil then
        text = completion_item.insertText or text
      end
      if word ~= text then
        abbr = abbr .. '~'
      end
    else
      word = completion_item.insertText or completion_item.label
      abbr = completion_item.label
    end

    -- determine item offset.
    local offset_fixed = false
    if not offset_fixed and completion_item.textEdit then
      -- See https://github.com/microsoft/vscode/blob/master/src/vs/editor/contrib/suggest/completionModel.ts#L170
      for idx = completion_item.textEdit.range.start.character + 1, #context.before_line do
        if not Character.is_white(string.byte(context.before_line, idx)) then
          if string.find(word, string.sub(context.before_line, idx, -1), 1, true) == 1 then
            keyword_pattern_offset = math.min(keyword_pattern_offset, idx)
            offset_fixed = true
            break
          end
        end
      end
    end
    if not offset_fixed then
      -- TODO: We should check this implementation respecting what is VSCode does.
      local leading_word_byte = string.byte(word, 1)
      if not Character.is_alpha(leading_word_byte) then
        for idx = #context.before_line, 1, -1 do
          local target_byte = string.byte(context.before_line, idx)
          if Character.is_white(target_byte) then
            break
          end
          if leading_word_byte == target_byte then
            local part = string.sub(context.before_line, idx, -1)
            if string.find(word, part, 1, true) == 1 then
              keyword_pattern_offset = math.min(keyword_pattern_offset, idx)
              offset_fixed = true
            end
            break
          end
        end
      end
    end

    -- Remove invalid chars from word without already allowed range.
    --   `func`($0)
    --   `class`="$0"
    --   `variable`$0
    --   `"json-props"`: "$0"
    local leading = (args.keyword_pattern_offset - keyword_pattern_offset)
    word = string.match(word, '^' .. ('.'):rep(leading) .. '[^%s=%(%$\'"]+')
    abbr = string.gsub(string.gsub(abbr, '^%s*', ''), '%s*$', '')

    table.insert(complete_items, {
      word = word;
      abbr = abbr;
      kind = vim.lsp.protocol.CompletionItemKind[completion_item.kind] or nil;
      user_data = {
        compe = {
          request_position = request.position;
          completion_item = completion_item;
        };
      };
      filter_text = completion_item.filterText or nil;
      sort_text = completion_item.sortText or nil;
      preselect = completion_item.preselect or false;
    })
  end

  return {
    items = complete_items,
    incomplete = response.incomplete or false,
    keyword_pattern_offset = keyword_pattern_offset,
  }
end

return Helper

