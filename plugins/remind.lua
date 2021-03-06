local remind = {}
local functions = require('functions')
remind.command = 'remind <duration> <message>'
function remind:init(configuration)
	self.database.reminders = self.database.reminders or {}
	remind.triggers = functions.triggers(self.info.username, configuration.command_prefix):t('remind', true).table
	remind.doc = configuration.command_prefix .. 'remind <duration> <message> - Repeats a message after a duration of time, in minutes. The maximum length of a reminder is %s characters. The maximum duration of a timer is %s minutes. The maximum number of reminders for a group is %s. The maximum number of reminders in private is %s.'
	remind.doc = remind.doc:format(configuration.remind.max_length, configuration.remind.max_duration, configuration.remind.max_reminders_group, configuration.remind.max_reminders_private)
end
function remind:action(msg, configuration)
	local input = functions.input(msg.text)
	if not input then
		functions.send_reply(msg, remind.doc, true)
		return
	end
	local duration = tonumber(functions.get_word(input, 1))
	if not duration then
		functions.send_reply(msg, remind.doc, true)
		return
	end
	if duration < 1 then
		duration = 1
	elseif duration > configuration.remind.max_duration then
		duration = configuration.remind.max_duration
	end
	local message
	if msg.reply_to_message and #msg.reply_to_message.text > 0 then
		message = msg.reply_to_message.text
	elseif functions.input(input) then
		message = functions.input(input)
	else
		functions.send_reply(msg, remind.doc, true)
		return
	end
	if #message > configuration.remind.max_length then
		functions.send_reply(msg, 'The maximum length of reminders is ' .. configuration.remind.max_length .. '.')
		return
	end
	local chat_id_str = tostring(msg.chat.id)
	local output
	self.database.reminders[chat_id_str] = self.database.reminders[chat_id_str] or {}
	if msg.chat.type == 'private' and functions.table_size(self.database.reminders[chat_id_str]) >= configuration.remind.max_reminders_private then
		output = 'Sorry, you already have the maximum number of reminders.'
	elseif msg.chat.type ~= 'private' and functions.table_size(self.database.reminders[chat_id_str]) >= configuration.remind.max_reminders_group then
		output = 'Sorry, this group already has the maximum number of reminders.'
	else
		table.insert(self.database.reminders[chat_id_str], {
			time = os.time() + (duration * 60),
			message = message
		})
		output = string.format(
			'I will remind you in %s minute%s!',
			duration,
			duration == 1 and '' or 's'
		)
	end
	functions.send_reply(msg, output, true)
end
function remind:cron(configuration)
	local time = os.time()
	for chat_id, group in pairs(self.database.reminders) do
		for k, reminder in pairs(group) do
			if time > reminder.time then
				local output = functions.style.enquote('Reminder', reminder.message)
				local res = functions.send_message(chat_id, output, true, nil, true)
				if res or not configuration.remind.persist then
					group[k] = nil
				end
			end
		end
	end
end

return remind