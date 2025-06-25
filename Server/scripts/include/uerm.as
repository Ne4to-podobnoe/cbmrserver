enum Callbacks
{
	ServerUpdate_c 			= 1,
	PlayerUpdate_c 			= 2,
	PlayerConnect_c 		= 3,
	PlayerChat_c 			= 4,
	PlayerDisconnect_c 		= 5,
	PlayerAttachesUpdate_c 	= 6,
	PlayerTakeItem_c 		= 7,
	PlayerDropItem_c 		= 8,
	PlayerDialogAction_c 	= 9,
	PlayerShootPlayer_c 	= 10,
	PlayerPressPlayer_c 	= 11,
	PlayerShoot_c 			= 12,
	PlayerConsole_c 		= 13,
	PlayerDeath_c 			= 14,
	PlayerRespawn_c 		= 15,
	WorldLoaded_c			= 16,
	PlayerHitPlayer_c	 	= 17,
	PlayerExploreCorpse_c	= 18,
	PlayerClickObject_c 	= 19,
	PlayerShootObject_c 	= 20,
	PlayerUseDoorButton_c	= 21,
	PlayerUseItem_c			= 22,
	PlayerUse914_c			= 23,
	FineItem_c				= 24,
	WorldUpdate_c			= 25,
	PlayerClickGui_c		= 26,
	PlayerVoice_c			= 27,
	PlayerTeleportElevator_c = 28,
	PlayerSelectItem_c		= 29,
	ServerConsole_c			= 30,
	ServerRestart_c			= 31,
	PlayerShootNPC_c		= 32,
	PlayerKeyAction_c		= 33,
	OnLog_c					= 34
}

const string[] EventCallbacks = 
{
	"",
	"OnServerUpdate", 
	"OnPlayerUpdate",
	"OnPlayerConnect",
	"OnPlayerChat",
	"OnPlayerDisconnect",
	"OnPlayerAttachesUpdate",
	"OnPlayerTakeItem",
	"OnPlayerDropItem",
	"OnPlayerDialogAction",
	"OnPlayerShootPlayer",
	"OnPlayerPressPlayer",
	"OnPlayerShoot",
	"OnPlayerConsole",
	"OnPlayerDeath",
	"OnPlayerRespawn",
	"OnWorldLoaded",
	"OnPlayerHitPlayer",
	"OnPlayerExploreCorpse",
	"OnPlayerClickObject",
	"OnPlayerShootObject",
	"OnPlayerUseDoorButton",
	"OnPlayerUseItem",
	"OnPlayerUse914",
	"OnFineItem",
	"OnWorldUpdate",
	"OnPlayerClickGUIElement",
	"OnPlayerVoice",
	"OnPlayerTeleportElevator",
	"OnPlayerSelectItem",
	"OnServerConsole",
	"OnServerRestart",
	"OnPlayerShootNPC",
	"OnPlayerKeyAction",
	"OnLogMessage"
};

// You can register a callback for an indefinite number of functions.
void RegisterCallback(int callbackIndex, string func) // You can use your custom functions in func argument, the arguments count and types must be the same
{
	if(!RegisterEventCallback(callbackIndex, func)) print("ERROR: Can't register " + EventCallbacks[callbackIndex] + " callback for " + func + " function.");
}

void RegisterCallback(int callbackIndex)
{
	RegisterEventCallback(callbackIndex, EventCallbacks[callbackIndex]);
}

void RegisterAllCallbacks()
{
	RegisterCallback(ServerUpdate_c);
	RegisterCallback(PlayerUpdate_c);
	RegisterCallback(PlayerConnect_c);
	RegisterCallback(PlayerChat_c);
	RegisterCallback(PlayerDisconnect_c);
	RegisterCallback(PlayerAttachesUpdate_c);
	RegisterCallback(PlayerTakeItem_c);
	RegisterCallback(PlayerDropItem_c);
	RegisterCallback(PlayerDialogAction_c);
	RegisterCallback(PlayerShootPlayer_c);
	RegisterCallback(PlayerPressPlayer_c);
	RegisterCallback(PlayerShoot_c);
	RegisterCallback(PlayerConsole_c);
	RegisterCallback(PlayerDeath_c);
	RegisterCallback(PlayerRespawn_c);
	RegisterCallback(WorldLoaded_c);
	RegisterCallback(PlayerHitPlayer_c);
	RegisterCallback(PlayerExploreCorpse_c);
	RegisterCallback(PlayerClickObject_c);
	RegisterCallback(PlayerShootObject_c);
	RegisterCallback(PlayerUseDoorButton_c);
	RegisterCallback(PlayerUseItem_c);
	RegisterCallback(PlayerUse914_c);
	RegisterCallback(FineItem_c);
	RegisterCallback(WorldUpdate_c);
	RegisterCallback(PlayerClickGui_c);
	RegisterCallback(PlayerVoice_c);
	RegisterCallback(PlayerTeleportElevator_c);
	RegisterCallback(PlayerSelectItem_c);
	RegisterCallback(ServerConsole_c);
	RegisterCallback(ServerRestart_c);
	RegisterCallback(PlayerShootNPC_c);
	RegisterCallback(PlayerKeyAction_c);
	RegisterCallback(OnLog_c);
}

enum Dialog
{
	DIALOG_TYPE_MESSAGE	= 0,
	DIALOG_TYPE_LIST	= 1,
	DIALOG_TYPE_INPUT	= 2
}

enum DefaultModels
{
	CLASS_D_MODEL 		= 1,
	HAZMAT_MODEL 		= 2,
	SCP_173_MODEL		= 3,
	SCP_106_MODEL		= 4,
	SCP_049_MODEL		= 5,
	SCP_939_MODEL 		= 6,
	SCP_966_MODEL		= 7,
	SCP_096_MODEL		= 8,
	GUARD_MODEL			= 9,
	MTF_MODEL			= 10,
	CHAOS_MODEL			= 11,
	ZOMBIE_MODEL		= 12,
	ZOMBIE_GUARD_MODEL	= 13,
	SCP_999_MODEL		= 14,
	SCP_860_MODEL		= 15,
	GOC_MODEL			= 16
}

enum DefaultModelTextures
{
	CLASS_D_1_TEXTURE 		= 1,
	CLASS_D_2_TEXTURE 		= 2,
	CLASS_D_3_TEXTURE 		= 3,
	CLASS_D_4_TEXTURE 		= 4,
	CLASS_D_5_TEXTURE 		= 5,
	CLASS_D_6_TEXTURE 		= 6,
	HAZMAT_TEXTURE 			= 7,
	CORPSE_CLASS_D_TEXTURE 	= 8,
	HAZMAT_HEAVY_TEXTURE	= 9,
	SCIENTIST_1_TEXTURE		= 10,
	SCIENTIST_2_TEXTURE		= 11,
	SCIENTIST_3_TEXTURE		= 12,
	SCIENTIST_4_TEXTURE		= 13,
	SCIENTIST_5_TEXTURE		= 14,
	SCIENTIST_6_TEXTURE		= 15,
	SCIENTIST_7_TEXTURE		= 16,
	JANITOR_TEXTURE			= 17,
	CHAOS_TEXTURE			= 18,
	MTF_TEXTURE				= 19,
	GUARD_TEXTURE			= 20,
	CLASS_D_ZOMBIE_TEXTURE	= 21,
	SCIENTIST_ZOMBIE_TEXTURE = 22,
	JANITOR_ZOMBIE_TEXTURE	 = 23,
	HAZMAT_ZOMBIE_TEXTURE	 = 24,
	MTF_COMMANDER_TEXTURE	 = 25,
	MTF_MEDIC_TEXTURE		 = 26,
	MTF_SERGEANT_TEXTURE	 = 27,
	SCP_096_BLOODY_TEXTURE	 = 28,
	CHAOS_COMMANDER_TEXTURE	 = 29,
	GOC_TEXTURE				 = 30
}

enum PlayerAnimations
{
	PLAYER_MODEL_ANIMATION_IDLE = 1,
	PLAYER_MODEL_ANIMATION_WALK = 2,
	PLAYER_MODEL_ANIMATION_RUN = 3,
	PLAYER_MODEL_ANIMATION_SITTING_IDLE = 4,
	PLAYER_MODEL_ANIMATION_SITTING_WALK = 5,
	PLAYER_MODEL_ANIMATION_FALLING = 6,
	PLAYER_MODEL_ANIMATION_FELL = 7,
	PLAYER_MODEL_ANIMATION_INJURED_IDLE = 8,
	PLAYER_MODEL_ANIMATION_INJURED_WALK = 9,
	PLAYER_MODEL_ANIMATION_IDLE_ARMED_PISTOL = 10,
	PLAYER_MODEL_ANIMATION_WALK_ARMED_PISTOL = 11,
	PLAYER_MODEL_ANIMATION_RUN_ARMED_PISTOL = 12,
	PLAYER_MODEL_ANIMATION_SITTING_IDLE_ARMED_PISTOL = 13,
	PLAYER_MODEL_ANIMATION_SITTING_WALK_ARMED_PISTOL = 14,
	PLAYER_MODEL_ANIMATION_IDLE_ARMED_RIFLE = 15,
	PLAYER_MODEL_ANIMATION_WALK_ARMED_RIFLE = 16,
	PLAYER_MODEL_ANIMATION_RUN_ARMED_RIFLE = 17,
	PLAYER_MODEL_ANIMATION_SITTING_IDLE_ARMED_RIFLE = 18,
	PLAYER_MODEL_ANIMATION_SITTING_WALK_ARMED_RIFLE = 19,
	PLAYER_MODEL_ANIMATION_ZOMBIE_HIT = 20
}
enum DefaultAttaches
{
	GASMASK_ATTACHMODEL 			= 1,
	GASMASK_FINE_ATTACHMODEL 		= 2,
	GASMASK_VERYFINE_ATTACHMODEL 	= 3,
	GASMASK_HEAVY_ATTACHMODEL 		= 4,

	VEST_ATTACHMODEL 				= 5,
	VEST_FINE_ATTACHMODEL 			= 6,

	HELMET_ATTACHMODEL 				= 7,

	NVG_ATTACHMODEL 				= 8,
	NVG_FINE_ATTACHMODEL 			= 9,
	NVG_VERYFINE_ATTACHMODEL 		= 10,

	SCRAMBLE_ATTACHMODEL 			= 11,
	SCRAMBLE_FINE_ATTACHMODEL 		= 12,

	SCP427_ATTACHMODEL 				= 13,

	CAP_ATTACHMODEL 				= 14,
	SCP268_ATTACHMODEL 				= 15,
	SCP268_FINE_ATTACHMODEL 		= 16,

	SCP714_ATTACHMODEL 				= 17,
	SCP714_COARSE_ATTACHMODEL 		= 18,

	WEAPON_M4A1_ATTACHMODEL 		= 19,
	WEAPON_GLOCK_ATTACHMODEL 		= 20,
	WEAPON_M60_ATTACHMODEL 			= 21,
	WEAPON_SR_ATTACHMODEL 			= 22,
	WEAPON_MP5_ATTACHMODEL 			= 23,
	WEAPON_FS_ATTACHMODEL 			= 24,
	WEAPON_VECTOR_ATTACHMODEL 		= 25,
	WEAPON_CUFFS_ATTACHMODEL 		= 26,
	WEAPON_CUFFED_ATTACHMODEL 		= 27,
	SCP035_ATTACHMODEL				= 28,
	FINE_HELMET_ATTACHMODEL			= 29,
	WEAPON_P90_ATTACHMODEL 			= 30,
	WEAPON_MP7_ATTACHMODEL 			= 31,
	WEAPON_M134_ATTACHMODEL 		= 32,
	WEAPON_VIEWMODEL096_ATTACHMODEL = 33,
	WEAPON_VIEWMODEL049_ATTACHMODEL = 34,
	WEAPON_VIEWMODEL106_ATTACHMODEL = 35,
	WEAPON_VIEWMODEL173_ATTACHMODEL = 36,
	WEAPON_VIEWMODEL966_ATTACHMODEL = 37
}

enum AttachesParts // Default reserved attach parts for SetAttach
{
	ATTACH_FACE 	= 0,
	ATTACH_BODY 	= 1,
	ATTACH_HEAD 	= 2,
	ATTACH_NECK 	= 3,
	ATTACH_FINGER 	= 4,
	ATTACH_WEAPON	= 5,
	ATTACH_WRIST	= 6
}

enum DefaultWeapons
{
	WEAPON_M4A1 = 1,
	WEAPON_GLOCK = 2,
	WEAPON_M60 = 3,
	WEAPON_SR = 4,
	WEAPON_MP5 = 5,
	WEAPON_FS = 6,
	WEAPON_VECTOR = 7,
	WEAPON_CUFFS = 8,
	WEAPON_CUFFED = 9,
	WEAPON_P90 = 10,
	WEAPON_MP7 = 11,
	WEAPON_M134 = 12,
	WEAPON_VIEWMODEL096 = 13,
	WEAPON_VIEWMODEL049 = 14,
	WEAPON_VIEWMODEL106 = 15,
	WEAPON_VIEWMODEL173 = 16,
	WEAPON_VIEWMODEL966 = 17
}

enum RoomIdentifiers
{
	// ~ LCZ
	r_room1_storage = 0,
	r_room1_dead_end_lcz = 1,
	r_cont1_005 = 2,
	r_cont1_173 = 3, r_cont1_173_intro = 4, r_cont1_205 = 5, r_cont1_914 = 6,
	r_room2_lcz = 7, r_room2_2_lcz = 8, r_room2_3_lcz = 9, r_room2_4_lcz = 10, r_room2_5_lcz = 11, r_room2_6_lcz = 12, r_room2_7_lcz = 13,
	r_room2_closets = 14,
	r_room2_elevator = 15,
	r_room2_gw = 16, r_room2_gw_2 = 17,
	r_room2_js = 18,
	r_room2_sl = 19,
	r_room2_storage = 20,
	r_room2_tesla_lcz = 21,
	r_room2_test_lcz = 22,
	r_cont2_012 = 23, r_cont2_427_714_860_1025 = 24, r_cont2_500_1499 = 25, r_cont2_1123 = 26,
	r_room2c_lcz = 27, r_room2c_2_lcz = 28,
	r_room2c_gw_lcz = 29, r_room2c_gw_2_lcz = 30,
	r_cont2c_066_1162_arc = 31,
	r_room3_storage = 32,
	r_room3_lcz = 33, r_room3_2_lcz = 34, r_room3_3_lcz = 35,
	r_cont3_372 = 36,
	r_room4_lcz = 37, r_room4_2_lcz = 38,
	r_room4_ic = 39,
	// ~ CHECKPOINT
	r_room2_checkpoint_lcz_hcz = 40,
	// ~ HCZ
	r_room1_dead_end_hcz = 41,
	r_cont1_035 = 42, r_cont1_079 = 43, r_cont1_106 = 44, r_cont1_895 = 45,
	r_room2_hcz = 46, r_room2_2_hcz = 47, r_room2_3_hcz = 48, r_room2_4_hcz = 49, r_room2_5_hcz = 50, r_room2_6_hcz = 51, r_room2_7_hcz = 52,
	r_room2_mt = 53,
	r_room2_nuke = 54,
	r_room2_servers_hcz = 55,
	r_room2_shaft = 56,
	r_room2_tesla_hcz = 57,
	r_room2_test_hcz = 58,
	r_cont2_008 = 59, r_cont2_049 = 60, r_cont2_409 = 61,
	r_room2c_hcz = 62, r_room2c_2_hcz = 63, r_room2c_3_hcz = 64,
	r_cont2c_096 = 65,
	r_room3_hcz = 66, r_room3_2_hcz = 67, r_room3_3_hcz = 68,
	r_cont3_513 = 69, r_cont3_966 = 70,
	r_room4_hcz = 71, r_room4_2_hcz = 72, r_room4_3_hcz = 73,
	// ~ CHECKPOINT
	r_room2_checkpoint_hcz_ez = 74,
	// ~ EZ
	r_gate_a_entrance = 75, r_gate_a = 76, r_gate_b_entrance = 77, r_gate_b = 78,
	r_room1_dead_end_ez = 79,
	r_room1_lifts = 80,
	r_room1_o5 = 81,
	r_room2_ez = 82, r_room2_2_ez = 83, r_room2_3_ez = 84, r_room2_4_ez = 85, r_room2_5_ez = 86, r_room2_6_ez = 87, r_room2_7_ez = 88,
	r_room2_cafeteria = 89,
	r_room2_ic = 90,
	r_room2_medibay = 91,
	r_room2_office = 92, r_room2_office_2 = 93, r_room2_office_3 = 94,
	r_room2_servers_ez = 95,
	r_room2_scientists = 96, r_room2_scientists_2 = 97,
	r_room2_tesla_ez = 98,
	r_cont2_860_1 = 99,
	r_room2c_ez = 100, r_room2c_2_ez = 101,
	r_room2c_ec = 102,
	r_room3_gw = 103,
	r_room3_office = 104,
	r_room3_ez = 105, r_room3_2_ez = 106, r_room3_3_ez = 107, r_room3_4_ez = 108,
	r_room4_ez = 109, r_room4_2_ez = 110,
	// ~ OTHERS
	r_dimension_106 = 111, r_dimension_1499 = 112,
	r_room2_closets_2 = 113,
	//
	r_gate_a_b = 114,
	r_cont3_009 = 115,
	r_room2_tesla_2_hcz = 116,
	r_RESERVED = 300 // Rooms ID to 300 are reserved for future versions of UERM
}

enum EventIdentifiers
{
	// ~ LCZ
	e_room1_dead_end_106 = 0,
	e_room1_storage = 1,
	e_cont1_005 = 2,
	e_cont1_173 = 3, e_cont1_173_intro = 4,
	e_cont1_205 = 5,
	e_cont1_914 = 6,
	e_room2_2_lcz_fan = 7,
	e_room2_closets = 8,
	e_room2_elevator = 9,
	e_room2_gw_2 = 10,
	e_room2_storage = 11,
	e_room2_sl = 12,
	e_room2_test_lcz_173 = 13,
	e_cont2_012 = 14,
	e_cont2_500_1499 = 15,
	e_cont2_1123 = 16,
	e_cont2c_066_1162_arc = 17,
	e_room3_storage = 18,
	e_cont3_372 = 19,
	e_room4_ic = 20,
	// ~ HCZ
	e_cont1_035 = 21,
	e_cont1_079 = 22,
	e_cont1_106 = 23,
	e_cont1_895 = 24,
	e_room2_2_hcz_106 = 25,
	e_room2_4_hcz_106 = 26,
	e_room2_5_hcz_106 = 27,
	e_room2_6_hcz_smoke = 28, e_room2_6_hcz_173 = 29,
	e_room2_mt = 30,
	e_room2_nuke = 31,
	e_room2_servers_hcz = 32,
	e_room2_shaft = 33,
	e_room2_test_hcz = 34,
	e_cont2_008 = 35,
	e_cont2_049 = 36,
	e_cont2_409 = 37,
	e_room3_hcz_duck = 38, e_room3_hcz_1048 = 39,
	e_room3_2_hcz_guard = 40,
	e_cont3_513 = 41,
	e_cont3_966 = 42,
	e_room4_2_hcz_d = 43,
	// ~ EZ
	e_gate_b_entrance = 44, e_gate_b = 45,
	e_gate_a_entrance = 46, e_gate_a = 47,
	e_room1_dead_end_guard = 48,
	e_room2_ez_035 = 49,
	e_room2_2_ez_duck = 50,
	e_room2_6_ez_789_j = 51, e_room2_6_ez_guard = 52,
	e_room2_office = 53,
	e_room2_cafeteria = 54,
	e_room2_ic = 55,
	e_room2_medibay = 56,
	e_room2_scientists_2 = 57,
	e_cont2_860_1 = 58,
	e_room2c_ec = 59,
	e_room3_2_ez_duck = 60,
	// ~ OTHERS
	e_096_spawn = 61,
	e_106_victim = 62,
	e_106_victim_wall = 63,
	e_106_sinkhole = 64,
	e_173_appearing = 65,
	e_682_roar = 66,
	e_1048_a = 67,
	e_blackout = 68,
	e_checkpoint = 69,
	e_door_closing = 70,
	e_gateway = 71,
	e_tesla = 72,
	e_trick = 73, e_trick_item = 74,
	e_dimension_106 = 75, e_dimension_1499 = 76,
	e_gate_a_b = 77,
	e_cont3_009 = 78,
	e_broken_tesla = 79
}

enum ItemsIdentifiers
{
	// ~ [PAPER]
	it_paper = 0,
	it_oldpaper = 1,

	it_origami = 2,

	it_badge = 3,
	it_oldbadge = 4,

	it_ticket = 5,
	// ~ [SCPs AND VARIATIONS]
	it_scp005 = 6,
	it_coarse005 = 7,
	it_crystal005 = 8,

	it_scp148ingot = 9,
	it_scp148 = 10,

	it_cap = 11,
	it_scp268 = 12,
	it_fine268 = 13,

	it_scp420j = 14,
	it_cigarette = 15,
	it_joint = 16,
	it_joint_smelly = 17,

	it_scp427 = 18,
	it_scp500 = 19,
	it_scp500pill = 20,
	it_scp500pilldeath = 21,
	it_pill = 22,

	it_scp513 = 23,

	it_coarse714 = 24,
	it_scp714 = 25,
	it_fine714 = 26,
	it_ring = 27,

	it_scp860 = 28,
	it_fine860 = 29,

	it_scp1025 = 30,
	it_fine1025 = 31,
	it_book = 32,

	it_scp1123 = 33,

	it_scp1499 = 34,
	it_fine1499 = 35,

	it_scp2022 = 36,
	it_scp2022pill = 37,

	// ~ [MISC ITEMS]
	it_helmet = 38,

	it_vest = 39,
	it_finevest = 40,
	it_corrvest = 41,
	it_veryfinevest = 42,

	it_cup = 43,
	it_emptycup = 44,

	it_clipboard = 45,
	it_wallet = 46,

	it_electronics = 47,

	it_eyedrops = 48,
	it_eyedrops2 = 49,
	it_fineeyedrops = 50,
	it_veryfineeyedrops = 51,

	it_firstaid = 52,
	it_firstaid2 = 53,
	it_finefirstaid = 54,
	it_veryfinefirstaid = 55,

	it_gasmask = 56,
	it_finegasmask = 57,
	it_veryfinegasmask = 58,
	it_gasmask148 = 59,

	it_hazmatsuit = 60,
	it_finehazmatsuit = 61,
	it_veryfinehazmatsuit = 62,
	it_hazmatsuit148 = 63,

	it_nvg = 64,
	it_veryfinenvg = 65,
	it_finenvg = 66,
	it_scramble = 67,
	it_finescramble = 68,

	it_radio = 69,
	it_18vradio = 70,
	it_fineradio = 71,
	it_veryfineradio = 72,

	it_nav = 73,
	it_nav300 = 74,
	it_nav310 = 75,
	it_navulti = 76,

	it_e_reader = 77,
	it_e_reader20 = 78,
	it_e_readerulti = 79,

	it_bat = 80,
	it_coarsebat = 81,
	it_finebat = 82,
	it_veryfinebat = 83,
	it_killbat = 84,

	it_syringe = 85,
	it_finesyringe = 86,
	it_veryfinesyringe = 87,
	it_syringeinf = 88,

	// ~ [KEYCARDS, HANDS, KEYS, CARDS, COINS]
	it_key0 = 89,
	it_key1 = 90,
	it_key2 = 91,
	it_key3 = 92,
	it_key4 = 93,
	it_key5 = 94,
	it_key6 = 95,
	it_keyomni = 96,

	it_mastercard = 97,
	it_mastercard_golden = 98,
	it_playcard = 99,

	it_hand = 100,
	it_hand2 = 101,
	it_hand3 = 102,

	it_key_yellow = 103,
	it_key_white = 104,
	it_lostkey = 105,

	it_25ct = 106,
	it_coin = 107,

	it_pizza = 108,

	// ~ [GUNS]
	it_m4 = 109,
	it_glock = 110,
	it_m60 = 111,
	it_sr556 = 112,
	it_mp5 = 113,
	it_fs = 114,
	it_krissvector = 115,
	//
	it_finehelmet = 116,
	it_keyci = 117,
	it_p90 = 118,
	it_mp7 = 119,
	it_handcuffs = 120,
	it_m134 = 121,
	it_remington = 122,
	it_fine513 = 123,
	it_backpack = 124,
	it_ammocrate = 125,
	it_headphones = 126,
	it_RESERVETO = 500 // Items ID to 500 are reserved for future versions of UERM
}

enum DoorTypes
{
	DEFAULT_DOOR 	= 0,
	ELEVATOR_DOOR 	= 1,
	HEAVY_DOOR 		= 2,
	BIG_DOOR 		= 3,
	OFFICE_DOOR 	= 4,
	WOODEN_DOOR 	= 5,
	FENCE_DOOR 		= 6,
	ONE_SIDED_DOOR 	= 7,
	SCP_914_DOOR 	= 8
}

enum DoorAccess
{
	NONE,
	DOOR_KEYCARD,
	DOOR_DNA,
	DOOR_KEYPAD,
	DOOR_OWF,
	DOOR_ELEVATOR
}

enum DoorKeycards
{
	KEY_MISC = 0,
	KEY_CARD_6 = 1,
	KEY_CARD_0 = 2,
	KEY_CARD_1 = 3,
	KEY_CARD_2 = 4,
	KEY_CARD_3 = 5,
	KEY_CARD_4 = 6,
	KEY_CARD_5 = 7,
	KEY_CARD_OMNI = 8,
	KEY_005 = 9,
	KEY_HAND_WHITE = -1,
	KEY_HAND_BLACK = -2,
	KEY_HAND_YELLOW = -3,
	KEY_860 = -4,
	KEY_KEY = -5,
	KEY_KEY2 = -6,
	KEY_LOST_KEY = -66
}

enum SCP914
{
	ROUGH = -2,
	COARSE = -1,
	ONETOONE = 0,
	FINE = 1,
	VERYFINE = 2
}

enum KickCodes
{
	CODE_UNALLOWEDVERSION 	= 1,
	CODE_TOOMUCHPLAYERS 	= 2,
	CODE_WRONGSEED 			= 3,
	CODE_NOTRESPOND 		= 4,
	CODE_LOBBYFAILED 		= 5,
	CODE_STEAMAUTH			= 6,
	CODE_INVALIDPASSWORD	= 7,
	CODE_BANNED				= 8,
	CODE_KICKED				= 9,
	CODE_RESTART			= 10,
	CODE_INVALIDCONTENT		= 11,
	CODE_CUSTOMERROR		= 12
}

enum NPCTypes
{
	NPCType008_1 = 0, NPCType008_1_Surgeon = 1, NPCType035_Tentacle = 2, NPCType049 = 3, NPCType049_2 = 4, NPCType066 = 5, NPCType096 = 6,
	NPCType106 = 7, NPCType173 = 8, NPCType372 = 9, NPCType513_1 = 10, NPCType860_2 = 11, NPCType939 = 12,
	NPCType966 = 13, NPCType999 = 14, NPCType1048 = 15, NPCType1048_A = 16, NPCType1499_1 = 17,
	NPCTypeApache = 18, NPCTypeClerk = 19, NPCTypeD = 20, NPCTypeGuard = 21, NPCTypeMTF = 22, NPCTypeCockroach = 23
}

enum Fonts
{
	Font_Default = 0,
	Font_Default_Big = 1,
	Font_Digital = 2,
	Font_Digital_Big = 3,
	Font_Journal = 4,
	Font_Console = 5,
	Font_Credits = 6,
	Font_Credits_Big = 7,
	Font_Tahoma = 8,
	Font_Icons = 9,
	Font_Default_Medium = 10,
	Font_Icons_Big = 11
}

enum KeysTypes
{
	KEY_U = 0x01,
	KEY_I = 0x02,
	KEY_O = 0x04,
	KEY_P = 0x08,
	KEY_N = 0x10,
	KEY_M = 0x20,
	KEY_F2 = 0x40,
	KEY_F4 = 0x80,
	KEY_LMB = 0x100,
	KEY_RMB = 0x200,
	KEY_MMB = 0x400,
	KEY_F = 0x800,
	KEY_G = 0x1000,
	KEY_H = 0x2000,
	KEY_J = 0x4000,
	KEY_K = 0x8000,
	KEY_1 = 0x10000,
	KEY_2 = 0x20000,
	KEY_3 = 0x40000,
	KEY_4 = 0x80000,
	KEY_5 = 0x100000,
	KEY_6 = 0x200000,
	KEY_7 = 0x400000,
	KEY_8 = 0x800000,
	KEY_9 = 0x1000000,
	KEY_0 = 0x2000000,
	KEY_F9 = 0x4000000,
	KEY_F10 = 0x8000000,
	KEY_Z = 0x10000000,
	KEY_X = 0x20000000,
	KEY_JUMP = 0x40000000,
	KEY_RSHIFT = -2147483648
}

bool IsKeyPressed(int key, int newmask, int prevmask) { return (newmask & key) != 0 && (prevmask & key) == 0; }
bool IsKeyReleased(int key, int newmask, int prevmask) { return (newmask & key) == 0 && (prevmask & key) != 0; }

enum MouseTypes
{
	MOUSE_LMB = 0x01,
	MOUSE_RMB = 0x02,
	MOUSE_MMB = 0x04
}

bool IsMousePressed(int mask, int button) { return ((mask & button) != 0); } // For PlayerHitPlayer_c callback

const float ROOM_SCALE = 8.0 / 2048.0;

// Players range is 1..120
const int MAX_PLAYERS = 120;

const int MAX_ITEMS = 1280;
const int MAX_DOORS	= 1000;
const int MAX_ROOMS = 256;
const int MAX_EVENTS = 256;
const int MAX_OBJECTS = 256;
const int MAX_NPCS = 256;
const int MAX_CORPSE_INVENTORY = 10;
const int MAX_PLAYER_INVENTORY = 10;
const int MAX_PLAYER_TAGS = 6;
const int MAX_CORPSES = 200;

// Indexes starting from 0 without -1
const int MAX_ROOM_DOORS = 8; // 0..8