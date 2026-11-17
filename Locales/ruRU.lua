-- Русский (ruRU). Machine-assisted translation; needs native-speaker review (docs/LOCALIZATION.md).
-- Plural forms: _ONE (1, 21, 31...), _FEW (2-4, 22-24...), _MANY (0, 5-20, 25-30...).
local _, ns = ...

ns.Locale.Register("ruRU", function(L)
	-- Репутация
	L.LABEL_new = "Новый"
	L.LABEL_trusted = "Надёжный"
	L.LABEL_mixed = "Неоднозначный"
	L.LABEL_caution = "Осторожно"

	-- Роли
	L.ROLE_tank = "Танк"
	L.ROLE_healer = "Лекарь"
	L.ROLE_dps = "Боец"
	L.ROLE_unknown = "Роль неизвестна"

	-- Метки
	L.TAG_role_good = "Отлично в роли"
	L.TAG_communicator = "Хорошо общается"
	L.TAG_helpful = "Терпелив/помогает"
	L.TAG_efficient = "Эффективен"
	L.TAG_fair_loot = "Честен с добычей"
	L.TAG_stayed = "Остался до конца"
	L.TAG_knows_dungeon = "Знает подземелье"
	L.TAG_role_bad = "Плохо в роли"
	L.TAG_ninja = "Ниндзя-лутер"
	L.TAG_left_early = "Ушёл раньше"
	L.TAG_afk = "АФК"
	L.TAG_toxic = "Токсичен"
	L.TAG_reckless = "Безрассудные пуллы"
	L.TAG_ignores_mechanics = "Игнорит механики"

	-- Сводка (уведомление и история)
	L.FMT_RATED_ONCE = "Одна оценка: %.1f"
	L.FMT_RATED_TIMES_ONE = "%d оценка, средняя за последнее время %.1f"
	L.FMT_RATED_TIMES_FEW = "%d оценки, средняя за последнее время %.1f"
	L.FMT_RATED_TIMES_MANY = "%d оценок, средняя за последнее время %.1f"
	L.FMT_ROLE_ONCE = "%s: %.1f за 1 группу"
	L.FMT_ROLE_RUNS_ONE = "%s: %.1f за %d группу"
	L.FMT_ROLE_RUNS_FEW = "%s: %.1f за %d группы"
	L.FMT_ROLE_RUNS_MANY = "%s: %.1f за %d групп"
	L.FMT_TAGS = "Метки: %s"
	L.LIST_SEP = ", "
	L.FMT_NOTE = "Заметка: %s"
	L.FMT_MORE = "...и ещё %d"

	-- Уведомления
	L.TOAST_JOIN_PLAYER = "Вы уже играли с этим игроком"
	L.TOAST_JOIN_PLAYERS = "В вашей группе есть игроки, которых вы оценивали"
	L.BTN_RATE = "Оценить"

	-- «Оцените группу»
	L.ALERT_TITLE = "Оцените группу"
	L.ALERT_ONE_GROUP = "%s, ждут оценки: %d"
	L.ALERT_GROUPS = "Групп: %d, ждут оценки: %d"
	L.ALERT_TIP =
		"Нажмите, чтобы оценить всех в одном окне.\nЕсли закрыть, напоминание дождётся следующей группы."

	-- Страница оценки
	L.RATE_TITLE = "Оцените группу"
	L.RATE_TITLE_PLAYER = "Оценить игрока"
	L.RATE_HEADLINE_GROUPS = "Групп: %d, ждут оценки: %d"
	L.RATE_HEADLINE_SINGLE = "1 игрок из вашей группы"
	L.RATE_HEADLINE_PLAYERS_ONE = "%d игрок из вашей группы"
	L.RATE_HEADLINE_PLAYERS_FEW = "%d игрока из вашей группы"
	L.RATE_HEADLINE_PLAYERS_MANY = "%d игроков из вашей группы"
	L.RATE_NO_RUN = "Другие игроки"
	L.RATE_PROGRESS = "Оценено: %d из %d"
	L.RATE_ALL_DONE = "Все оценены. Спасибо!"
	L.RATE_HINT =
		"Нажмите на оценку, чтобы сохранить её. Нажмите на карточку для меток и заметки."
	L.RATE_ROLE_TIP = "Роль: %s. Нажмите, чтобы сменить."
	L.RATE_LAST_ROLE = "В прошлый раз: %s"
	L.RATE_NOTE_HINT = "Добавить заметку (необязательно)"
	L.RATE_SHOW_NEGATIVE = "Негативные..."
	L.RATE_SHOW_POSITIVE = "Позитивные..."
	L.RATE_FAILED = "Не удалось сохранить оценку (%s)."
	L.RATE_EMPTY = "Здесь некого оценивать."
	L.RATE_CAUGHT_UP = "Всё оценено"
	L.RATE_CAUGHT_UP_TEXT = "Никто не ждёт оценки. После следующей группы здесь появятся игроки,"
		.. " с которыми вы играли. Также можно нажать правой кнопкой на любого в группе."
	L.SCORE_1 = "1: Ужасно"
	L.SCORE_2 = "2: Плохо"
	L.SCORE_3 = "3: Нормально"
	L.SCORE_4 = "4: Хорошо"
	L.SCORE_5 = "5: Отлично"
	L.BTN_DONE = "Готово"
	L.BTN_SKIP = "Пропустить все"
	L.BTN_SKIP_TIP =
		"Больше не спрашивать об этих группах.\nИх всё ещё можно оценить на вкладке «Группы»."

	-- Окно и боковая панель
	L.NAV_RATE = "Оценка"
	L.NAV_SETTINGS = "Настройки"
	L.NAV_ABOUT = "Об аддоне"
	L.ABOUT_TITLE = "О SquadRank"
	L.RUNS_TITLE = "Ваши группы"

	-- Игроки и группы
	L.STAT_PLAYERS = "Встречено игроков"
	L.STAT_RATINGS = "Выставлено оценок"
	L.STAT_TRUSTED = "Надёжных игроков"
	L.SEARCH_HINT = "Поиск игроков"
	L.SEARCH_RUNS_HINT = "Поиск групп"
	L.COL_SCORE = "Оценка"
	L.COL_STATUS = "Статус"
	L.RUN_STATUS_PENDING = "Ждёт оценки"
	L.RUN_STATUS_DONE = "Оценено"
	L.RUN_STATUS_SKIPPED = "Пропущено"
	L.RUNS_HINT =
		"Нажмите на группу, чтобы оценить её или изменить оценки."
	L.TAB_PLAYERS = "Игроки"
	L.TAB_RUNS = "Группы"
	L.FILTER_LABEL = "Репутация"
	L.FILTER_ROLE = "Роль"
	L.FILTER_TAG = "Метка"
	L.FILTER_ALL = "Все"
	L.FILTER_FMT = "%s: %s"
	L.COUNT_FMT = "Показано: %d"
	L.COL_PLAYER = "Игрок"
	L.COL_LABEL = "Репутация"
	L.COL_RATINGS = "Оценок"
	L.COL_SEEN = "Последняя встреча"
	L.COL_INSTANCE = "Подземелье"
	L.COL_DATE = "Дата"
	L.COL_PLAYERS = "Группа"
	L.COL_RATED = "Оценено"
	L.EMPTY_PLAYERS =
		"Нет подходящих игроков. Соберите группу и оцените кого-нибудь."
	L.EMPTY_RUNS = "Пока нет записанных групп."
	L.MAIN_HINT =
		"Нажмите на игрока, чтобы увидеть историю. Правая кнопка — другие действия."
	L.RUN_PLAYERS_ONE = "%d игрок"
	L.RUN_PLAYERS_FEW = "%d игрока"
	L.RUN_PLAYERS_MANY = "%d игроков"
	L.RUN_RATED_FMT = "оценено %d/%d"
	L.RUN_GROUP_FMT = "Группа: %s"
	L.UNKNOWN_INSTANCE = "Неизвестное подземелье"
	L.UNKNOWN_ZONE = "открытый мир"
	L.MENU_RATE = "Оценить в SquadRank"
	L.MENU_HISTORY = "Показать историю"
	L.MENU_PURGE = "Удалить игрока"

	-- История игрока
	L.DETAIL_CLASS_LEVEL = "Уровень %s, %s"
	L.DETAIL_NO_RATINGS = "Оценок пока нет."
	L.DETAIL_IMPORTED = "перенесено из SquadRank 1.x"
	L.DETAIL_SEEN_SHORT = "Последняя встреча: %s"
	L.DETAIL_AVG_SINGLE = "по 1 оценке"
	L.DETAIL_AVG_RATINGS_ONE = "в среднем по %d оценке"
	L.DETAIL_AVG_RATINGS_FEW = "в среднем по %d оценкам"
	L.DETAIL_AVG_RATINGS_MANY = "в среднем по %d оценкам"
	L.DETAIL_HISTORY = "История"
	L.BTN_PURGE = "Удалить"

	-- Настройки
	L.SET_TOAST = "Показывать уведомление, когда входит оценённый игрок"
	L.SET_TOAST_TIP = "Один раз на игрока за группу, никогда в бою."
	L.SET_DURATION = "Длительность уведомления (секунды)"
	L.SET_DURATION_TIP = "Сколько времени уведомление остаётся на экране."
	L.SET_MIN = "Оценок для получения репутации"
	L.SET_MIN_TIP =
		"Игроки с меньшим числом оценок отмечаются как «Новый»."
	L.SET_PROMPT = "Предлагать оценить группу после её роспуска"
	L.SET_PROMPT_TIP_SHORT =
		"После подземелья или группы от 5 минут, когда вы покинете группу."
	L.SET_PROMPT_TIP = "После подземелья, рейда или группы в открытом мире от 5 минут"
		.. " вас будет ждать небольшое напоминание, когда вы покинете группу."
	L.SET_RECENT =
		"Использовать список недавних союзников Blizzard (только чтение)"
	L.SET_RECENT_TIP =
		"Ищет оцениваемых игроков по имени. Никогда не пишет в заметки Blizzard."
	L.SET_MINIMAP = "Показывать кнопку у миникарты"
	L.SET_MINIMAP_TIP =
		"Левый клик открывает SquadRank, правый — настройки. Перетащите, чтобы переместить."
	L.SET_SECTION_ALERTS = "Уведомления"
	L.SET_SECTION_REPUTATION = "Репутация"
	L.SET_SECTION_INTERFACE = "Интерфейс"
	L.SET_SECTION_DATA = "Ваши данные"
	L.BTN_DELETE_ALL = "Удалить всё"
	L.SET_PURGE_ALL = "Удалить все данные SquadRank"
	L.SET_PURGE_ALL_TIP =
		"Удаляет всех сохранённых игроков, оценки и группы. Настройки сохраняются."
	L.SET_PURGE_PLAYER = "Удалить одного игрока"
	L.SET_PURGE_PLAYER_TIP =
		"Открывает список игроков. Нажмите правой кнопкой на игрока и выберите «Удалить»."
	L.BTN_OPEN_LIST = "Открыть список"
	L.CONFIRM_PURGE_ALL =
		"Удалить всех игроков, оценки и группы, сохранённые SquadRank?\nЭто нельзя отменить."
	L.CONFIRM_PURGE_PLAYER = "Удалить игрока %s и все ваши оценки для него?"

	-- Об аддоне
	L.ABOUT_BY = "автор: %s"
	L.ABOUT_VERSION = "Версия %s"
	L.ABOUT_TAGLINE = "Помните, кто сделал вашу группу отличной, а кто нет."
	L.ABOUT_F1_TITLE = "Оценка в один клик"
	L.ABOUT_F1_TEXT = "Когда группа распадается, оцените всех в одном месте. Один клик на игрока,"
		.. " метки и заметки по желанию."
	L.ABOUT_F2_TITLE = "Знайте, кто входит"
	L.ABOUT_F2_TEXT = "Ненавязчивое уведомление, когда в группу входит игрок, которого вы оценивали,"
		.. " с его оценкой и вашими заметками."
	L.ABOUT_F3_TITLE = "Приватность прежде всего"
	L.ABOUT_F3_TEXT =
		"Всё хранится на вашем компьютере. Ничего не отправляется, не публикуется и не загружается."
	L.ABOUT_COMMANDS = "Команды"
	L.ABOUT_PRIVACY = "SquadRank не использует сеть и никогда не пишет в заметки Blizzard."
		.. " Ваши оценки хранятся только в вашем файле SavedVariables."

	-- Кнопка у миникарты
	L.MINIMAP_PENDING_ONE = "%d игрок ждёт оценки"
	L.MINIMAP_PENDING_FEW = "%d игрока ждут оценки"
	L.MINIMAP_PENDING_MANY = "%d игроков ждут оценки"
	L.MINIMAP_LEFT = "Левый клик: открыть SquadRank"
	L.MINIMAP_RIGHT = "Правый клик: настройки"
	L.MINIMAP_DRAG = "Перетаскивание: переместить кнопку"

	-- Окно отладки
	L.DEBUG_TITLE = "Отчёт отладки SquadRank"
	L.DEBUG_HINT =
		"Щёлкните в поле, нажмите Ctrl+A, затем Ctrl+C, чтобы скопировать."
	L.BTN_SELFTEST = "Запустить самопроверку"
	L.BTN_REFRESH = "Обновить"

	-- Сообщения в чате
	L.MSG_COMBAT = "Недоступно в бою. Попробуйте после боя."
	L.MSG_READONLY =
		"Режим только для чтения (%s). Ничего не будет сохранено. См. /sr debug."
	L.MSG_TOO_LARGE =
		"Файл данных слишком большой и может не загрузиться. Используйте /sr purge."
	L.MSG_NOT_FOUND = "Нет сохранённого игрока с именем '%s'."
	L.MSG_AMBIGUOUS =
		"Под '%s' подходит несколько игроков. Добавьте часть после дефиса:"
	L.MSG_PURGED = "Удалено: %s."
	L.MSG_PURGED_ALL = "Все данные SquadRank удалены."
	L.MSG_NO_PENDING = "Нет групп, ожидающих оценки."
	L.MSG_UNIT_UNKNOWN =
		"Данные этого игрока сейчас недоступны. Попробуйте чуть позже."
	L.MSG_SELFTEST =
		"Самопроверка: успешно %d, ошибок %d, сведений %d. Подробности: /sr debug."
	L.MSG_LIST_NONE = "Нет подходящих сохранённых игроков."
	L.MSG_LIST_ONE = "%s - %s, %d оценка"
	L.MSG_LIST_FEW = "%s - %s, %d оценки"
	L.MSG_LIST_MANY = "%s - %s, %d оценок"
	L.MSG_LIST_MORE = "...и ещё %d. Откройте /sr, чтобы увидеть весь список."
	L.MSG_LISTS_SIMPLE =
		"Простой режим списков: %s. Введите /reload, чтобы применить."
	L.STATE_ON = "вкл."
	L.STATE_OFF = "выкл."
	L.MSG_LOCALE_SET =
		"Язык для разработки: %s. Введите /reload, чтобы применить."
	L.MSG_LOCALE_CLEARED =
		"Язык для разработки сброшен. Введите /reload, чтобы вернуть язык игры."
	L.MSG_LOCALE_USAGE =
		"Использование: /sr debug locale <код> (например, deDE) или /sr debug locale off."
	L.MSG_HELP_1 = "/sr - открыть окно"
	L.MSG_HELP_2 =
		"/sr rate [имя] - оценить игрока, без имени - последнюю группу"
	L.MSG_HELP_3 = "/sr list [текст] - список сохранённых игроков"
	L.MSG_HELP_4 = "/sr purge <имя> | all - удалить сохранённые данные"
	L.MSG_HELP_5 =
		"/sr settings, /sr about, /sr minimap - настройки, об аддоне, показать или скрыть кнопку"
	L.MSG_HELP_6 =
		"/sr debug - открыть отчёт отладки;  /sr selftest - проверить API игры"

	-- Group types, bosses, quests and support (0.9)
	L.CAT_quest = "Задания"
	L.CAT_world = "Открытый мир"
	L.CAT_dungeon = "Подземелье"
	L.CAT_raid = "Рейд"
	L.CAT_worldraid = "Мировой рейд"
	L.CAT_pvp = "PvP"
	L.CAT_wpvp = "Мировое PvP"
	L.RUN_IN_quest = "Задания: %s"
	L.RUN_IN_worldraid = "Мировой рейд: %s"
	L.RUN_IN_wpvp = "Мировое PvP: %s"
	L.FILTER_TYPE = "Тип"
	L.COL_TYPE = "Тип"
	L.RUN_TIP_BOSSES = "Побеждённые боссы"
	L.RUN_TIP_QUESTS_DONE = "Выполненные задания"
	L.RUN_TIP_QUESTS_PROGRESS = "Задания с прогрессом"
	L.RUN_TIP_DURATION = "Длительность: %d мин."
	L.RUN_TIP_NOTHING = "Боссы и задания не записаны."
	L.QUEST_FALLBACK = "Задание %d"
	L.UNKNOWN_BOSS = "Неизвестный босс"
	L.TAG_leader = "Хорошо вёл группу"
	L.TAG_offspec = "Нужда не по спеку"
	L.ABOUT_SUPPORT_TITLE = "Поддержать SquadRank"
	L.ABOUT_SUPPORT_TEXT = "Нравится SquadRank? Угостите меня кофе:"
	L.ABOUT_SUPPORT_HINT = "Нажмите на ссылку, затем Ctrl+C, чтобы скопировать."
	L.RUN_BOSSES_ONE = "%d босс"
	L.RUN_BOSSES_FEW = "%d босса"
	L.RUN_BOSSES_MANY = "%d боссов"
	L.RUN_QUESTS_ONE = "%d задание"
	L.RUN_QUESTS_FEW = "%d задания"
	L.RUN_QUESTS_MANY = "%d заданий"

	-- Avoid list, stats, sharing, sounds, wipes (0.9)
	L.NAV_STATS = "Статистика"
	L.STATS_TITLE = "Ваша статистика"
	L.STATS_GROUPS = "Записано групп"
	L.STATS_HOURS = "Часов в группах"
	L.STATS_BOSSES = "Побеждено боссов"
	L.STATS_QUESTS = "Выполнено заданий"
	L.STATS_TOP_GROUPED = "Чаще всего вместе"
	L.STATS_TOP_RATED = "Лучшие оценки"
	L.STATS_AVOIDED = "Список избегаемых"
	L.STATS_BY_TYPE = "Группы по типу"
	L.STATS_EMPTY = "Пока ничего нет."
	L.LABEL_avoid = "Избегать"
	L.MENU_AVOID = "Добавить в список избегаемых"
	L.MENU_UNAVOID = "Убрать из списка избегаемых"
	L.BTN_AVOID = "Избегать"
	L.BTN_UNAVOID = "Не избегать"
	L.MSG_AVOID_ADDED = "%s добавлен в список избегаемых."
	L.MSG_AVOID_REMOVED = "%s убран из списка избегаемых."
	L.TOAST_AVOID_PLAYER = "В группу вошёл игрок из вашего списка избегаемых"
	L.TOAST_AVOID_PLAYERS = "В группе есть игроки из вашего списка избегаемых"
	L.TOOLTIP_AVOID = "SquadRank: в списке избегаемых"
	L.SHARE_BTN = "Поделиться"
	L.SHARE_HINT = "Нажмите Ctrl+C, чтобы скопировать, и вставьте в чат."
	L.SHARE_NONE = "[SquadRank] %s: оценок пока нет."
	L.SHARE_ROLES = "Роли: %s."
	L.SET_AVOID = "Предупреждать, когда входит избегаемый игрок"
	L.SET_AVOID_TIP =
		"Красное предупреждение со звуком, даже если другие уведомления выключены."
	L.SET_SOUND = "Воспроизводить звуки"
	L.SET_SOUND_TIP =
		"Для напоминания об оценке, уведомлений о входе и предупреждений."
	L.SET_MIN_RUN = "Минимальное время в подземелье для напоминания (мин.)"
	L.SET_MIN_RUN_TIP =
		"Более короткие визиты сохраняются, но без запроса оценки. 0 — спрашивать всегда."
	L.SET_TOOLTIP = "Показывать SquadRank в подсказках игроков"
	L.SET_TOOLTIP_TIP =
		"Добавляет репутацию или предупреждение при наведении на игрока."
	L.SET_SHARE = "Разрешить делиться сводкой об игроке"
	L.SET_SHARE_TIP =
		"Добавляет кнопку «Поделиться» в историю: одна строка для чата. Заметки не включаются."
	L.STATS_GROUPED_ONE = "%d группа"
	L.STATS_GROUPED_FEW = "%d группы"
	L.STATS_GROUPED_MANY = "%d групп"
	L.RUN_WIPES_ONE = "%d вайп"
	L.RUN_WIPES_FEW = "%d вайпа"
	L.RUN_WIPES_MANY = "%d вайпов"
	L.TOOLTIP_RATED_ONE = "SquadRank: %s, %.1f по %d оценке"
	L.TOOLTIP_RATED_FEW = "SquadRank: %s, %.1f по %d оценкам"
	L.TOOLTIP_RATED_MANY = "SquadRank: %s, %.1f по %d оценкам"
	L.SHARE_RATED_ONE = "[SquadRank] %s: %s, в среднем %.1f по %d оценке."
	L.SHARE_RATED_FEW = "[SquadRank] %s: %s, в среднем %.1f по %d оценкам."
	L.SHARE_RATED_MANY = "[SquadRank] %s: %s, в среднем %.1f по %d оценкам."

	-- PvP page (1.0)
	L.NAV_PVP = "PvP"
	L.PVP_TITLE = "PvP и мировые рейды"
	L.PVP_VIEW_GROUPS = "Группы"
	L.PVP_VIEW_PLAYERS = "Встреченные игроки"
	L.PVP_INFO =
		"Поля боя, арены, мировое PvP и мировые рейды собраны здесь, чтобы не засорять другие списки."
	L.PVP_HINT =
		"Большие группы никогда не просят оценку. Нажмите на группу, чтобы оценить её."
	L.EMPTY_PVP_GROUPS = "Пока нет групп PvP или мировых рейдов."
	L.EMPTY_PVP_PLAYERS = "Пока никого не встречено в PvP или мировых рейдах."
	-- Уведомления вне группы
	L.SET_SECTION_CONTEXT = "Уведомления вне группы"
	L.SET_ALERT_WHISPER = "Уведомления о шёпоте"
	L.SET_ALERT_WHISPER_TIP =
		"Когда вам шепчет оценённый или избегаемый игрок. Сообщение не читается и не сохраняется."
	L.SET_ALERT_TARGET = "Уведомления о цели"
	L.SET_ALERT_TARGET_TIP =
		"Когда вы выбираете целью оценённого или избегаемого игрока."
	L.SET_ALERT_TRADE = "Уведомления об обмене"
	L.SET_ALERT_TRADE_TIP =
		"Когда оценённый или избегаемый игрок предлагает обмен."
	L.SET_ALERT_DUEL = "Уведомления о дуэли"
	L.SET_ALERT_DUEL_TIP =
		"Когда оценённый или избегаемый игрок вызывает вас на дуэль."
	L.SET_ALERT_COOLDOWN = "Интервал уведомлений (минуты)"
	L.SET_ALERT_COOLDOWN_TIP =
		"Не больше одного уведомления об игроке за это время. 0 — каждый раз."
	L.TOAST_ALERT_whisper = "Сохранённый игрок шепнул вам"
	L.TOAST_ALERT_target = "Вы выбрали сохранённого игрока"
	L.TOAST_ALERT_trade = "Запрос обмена от сохранённого игрока"
	L.TOAST_ALERT_duel = "Вызов на дуэль от сохранённого игрока"

	-- Что нового и приветствие (1.5)
	L.WHATS_NEW_TITLE = "Что нового в SquadRank %s"
	L.WHATS_NEW_SUBTITLE =
		"Более тихий способ следить за тем, как идут дела у вашей группы."
	L.WHATS_NEW_F1_TITLE = "Уведомления вне группы"
	L.WHATS_NEW_F1_TEXT = "Уведомления о шёпоте, цели, обмене и дуэли для сохранённых игроков."
		.. " У каждого свой переключатель, по умолчанию они выключены."
	L.WHATS_NEW_F2_TITLE = "Один интервал на игрока"
	L.WHATS_NEW_F2_TEXT =
		"Не больше одного уведомления об игроке за все четыре случая. Настройка от 0 до 180 минут; 0 — каждый раз."
	L.WHATS_NEW_F3_TITLE = "Список избегаемых важнее"
	L.WHATS_NEW_F3_TEXT = "Избегаемый игрок может вызвать красное предупреждение,"
		.. " даже если переключатель этого случая выключен. Интервал всё равно действует."
	L.WHATS_NEW_F4_TITLE = "Приватно и безопасно в бою"
	L.WHATS_NEW_F4_TEXT =
		"Текст шёпота никогда не читается и не сохраняется. В бою ничего не запрашивается; уведомления ждут окончания боя."
	L.WHATS_NEW_F5_TITLE = "Легко открыть снова"
	L.WHATS_NEW_F5_TEXT =
		"Это окно появляется один раз на версию. Введите /sr whatsnew в любое время или отключите его в настройках."
	L.WHATS_NEW_TIP =
		"Спасибо, что пользуетесь SquadRank. Ваша группа в надёжных руках."
	L.BTN_GOT_IT = "Понятно"
	L.BTN_OPEN_SETTINGS = "Открыть настройки"
	L.BTN_WHATSNEW = "Что нового"
	L.SET_WHATSNEW = "Показывать новое после обновления"
	L.SET_WHATSNEW_TIP =
		"Одно короткое окно на версию. Открыть снова можно командой /sr whatsnew."
	L.SET_CHAT_HELLO = "Приветствовать в чате при входе"
	L.SET_CHAT_HELLO_TIP =
		"Короткая строка SquadRank раз за сеанс, чтобы вы знали, что он следит за группами."
	L.MSG_HELLO = "|TInterface\\AddOns\\SquadRank\\Media\\Icon:16:16|t |cff33bbffSquadRank|r "
		.. "следит за тем, как идут дела у вашей группы. Введите |cffffd100/sr|r, чтобы открыть список."
	L.MSG_HELP_7 = "/sr whatsnew - показать, что нового в этой версии"
	L.MSG_HELP_8 =
		"/sr allies - показать сохранённых игроков из недавних союзников Blizzard"
	L.DETAIL_NO_ROLE_RATINGS = "Оценок по ролям пока нет."
	L.MSG_ALLIES_HEADER = "Недавние союзники среди сохранённых игроков:"
	L.MSG_ALLIES_NONE = "Среди недавних союзников нет сохранённых игроков."
	L.MSG_ALLIES_UNAVAILABLE =
		"Недавние союзники отключены или недоступны. Включите их в настройках."
end)
