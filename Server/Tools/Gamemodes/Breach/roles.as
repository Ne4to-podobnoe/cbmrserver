const int MAX_POSSIBLE_CATEGORIES = 32;

enum Roles
{
	ROLE_SPECTATOR,
	ROLE_CLASS_D,
	ROLE_JANITOR,
	ROLE_SCIENTIST,
	ROLE_GUARD,
	ROLE_MTF,
	ROLE_CHAOS,
	ROLE_SCP_173,
	ROLE_SCP_106,
	ROLE_SCP_939,
	ROLE_SCP_966,
	ROLE_SCP_049,
	ROLE_SCP_0492,
	ROLE_SCP_096,
	ROLE_SCP_0492_GUARD,
	ROLE_SCP_035,
	ROLE_SCP_999,
	ROLE_MTF_COMMANDER,
	ROLE_MTF_SERGEANT,
	ROLE_MTF_MEDIC,
	ROLE_CHAOS_COMMANDER,
	ROLE_CHAOS_GUNNER,
	ROLE_CHAOS_MEDIC,
	ROLE_SCP_860,
	ROLE_GOC,
	ROLE_GHOST
};

enum Categories
{
	CATEGORY_NONE,
	CATEGORY_STALEMATE,
	CATEGORY_INMATE,
	CATEGORY_STAFF,
	CATEGORY_SECURITY,
	CATEGORY_ANOMALY,
	CATEGORY_ANOMALYSTALEMATE,
	CATEGORY_GOC
};

class Role
{
	Role() { }
	Role(int id, string n, int ct, PlayerModel modelp, Color c, string task, array<Spawnpoint@> s = {}, array<string> Items = {}, bool sng = false, float dmg = 0.0, int health = 100, float ht = 0, bool godm = false)
	{
		name = n;
		roleid = id;
		category = ct;
		model = modelp;
		color = c;
		spawnPoints = s;
		rTask = task;
		single = sng;
		damage = dmg;
		damagemultiplier = 8.0 / (health / 12.5);
		hitTime = ht;
		items = Items;
		godmode = godm;

		if(!spawnPoints.empty()) {
			for(int i = spawnPoints.size() - 1; i >= 0; i--) {
				if(spawnPoints[i].room == NULL) spawnPoints.removeAt(i);
			}
			
			if(spawnPoints.empty()) {
				array<Room> rooms;
				for(int i = 0; i < MAX_ROOMS; i++) {
					Room r = world.GetRoomByIndex(i);
					if(r != NULL && 
					r.GetIdentifier() != r_cont1_173 && 
					r.GetIdentifier() != r_gate_a_b && 
					r.GetIdentifier() != r_gate_a && 
					r.GetIdentifier() != r_gate_b && 
					r.GetIdentifier() != r_gate_a_entrance &&
					r.GetIdentifier() != r_gate_b_entrance) rooms.push_back(r);
				}
				
				spawnPoints.push_back(Spawnpoint(vector3(0.0, 82, 0.0), 0.0, 0.0, rooms[rand(0, rooms.size() -1)]));
			}
		}
	}
	~Role()
	{
		
	}

	void SetRadio(float channel)
	{
		radioChannel = channel;
	}
	
	void SetFriend(Role@ role, bool b = true)
	{
		if(@role == null) return;
		friends[role.roleid] = b;
		role.friends[roleid] = b;
	}
	
	void SetRelative(Role@ role, bool b = true)
	{
		if(@role == null) return;
		relative[role.roleid] = b;
		role.relative[roleid] = b;
	}
	
	bool IsRelative(Role@ role)
	{
		if(@role == null) return false;
		return relative[role.roleid];
	}
	
	bool IsAFriend(Role@ role)
	{
		if(@role == null) return false;
		return friends[role.roleid];
	}
	
	float GetGenerationFactor()
	{
		return countOnRound;
	}
	
	void SetGenerationFactor(float cnt)
	{
		countOnRound = cnt;
	}
	
	void AddIdleSound(string sound)
	{
		idleSounds.push_back(sound);
	}
	
	void SetIdleSoundTime(float time)
	{
		idleSoundTime = time;
	}
	
	void SetTerminationAnnouncement(string announcement)
	{
		deadAnnouncement = announcement;
	}
	
	void SetAdditiveSingles(int count)
	{
		additiveSingles = count;
	}
	
	string GetFormatColor()
	{
		return "&colr[" + color.R() + " " + color.G() + " " + color.B() + "]";
	}

	string name;
	int roleid;
	int category;
	PlayerModel model;
	float countOnRound;
	int chancetoSpawn;
	bool single;
	float damage;
	float damagemultiplier;
	float hitTime;
	bool godmode;
	float radioChannel;
	int additiveSingles;
	Color color;
	array<Spawnpoint@> spawnPoints;
	string rTask;
	array<string> items;
	array<bool> friends(32);
	array<bool> relative(32);
	string deadAnnouncement;
	array<string> idleSounds;
	float idleSoundTime;
}

class Category
{
	Category() { }
	Category(int id, string n, Color c)
	{
		identifier = id;
		color = c;
		name = n;
	}
	~Category()
	{
		
	}
	
	string name;
	Color color;
	int identifier;
}

class EscapeSection
{
	EscapeSection() { }
	EscapeSection(vector3 offset, Room r, int ct, array<Role@> roles, Role@ assign)
	{ 
		TFormRoom(r, offset.x, offset.y, offset.z, x, y, z);
		room = r;
		category = ct;
		allowedRoles = roles;
		@toAssign = assign;
	}
	~EscapeSection()
	{
		
	}
	
	array<Role@> allowedRoles;
	float x, y, z;
	Room room;
	int category;
	Role@ toAssign;
}

namespace Roles
{
	array<Role@> roles;
	array<Category@> categories;
	array<EscapeSection@> escapeSec;

	void Initialize()
	{
		Clear();
		ClearCategories();
		ClearEscapeSections();
		
		Room cont1_173 = world.GetRoomByIdentifier(r_cont1_173);
		Room room3_storage = world.GetRoomByIdentifier(r_room3_storage);
		Room gate_b_entrance = world.GetRoomByIdentifier(r_gate_b_entrance);
		Room gate_b = world.GetRoomByIdentifier(r_gate_b);
		Room gate_a = world.GetRoomByIdentifier(r_gate_a);
		Room gate_a_b = world.GetRoomByIdentifier(r_gate_a_b);
		Room cont3_966 = world.GetRoomByIdentifier(r_cont3_966);
		Room room2_servers_hcz = world.GetRoomByIdentifier(r_room2_servers_hcz);
		
		Role@ Spectator = Role(ROLE_SPECTATOR, "Spectator", CATEGORY_STALEMATE, PlayerModel(0), Color(200, 200, 200), "");
		
		Role@ ClassD = Role(ROLE_CLASS_D, "Class D", CATEGORY_INMATE, PlayerModel(CLASS_D_MODEL), Color(212,113,0), "Evacuate the complex. Find salvation. Don't trust anyone.",
		{
			Spawnpoint(vector3(-2874.0, 470, 9366.3), 0.0, -90.0, cont1_173),
			Spawnpoint(vector3(-2874.0, 470, 8839.3), 0.0, -90.0, cont1_173),
			Spawnpoint(vector3(-2874.0, 470, 8333.9), 0.0, -90.0, cont1_173),
			Spawnpoint(vector3(-2874.0, 470, 7817.3), 0.0, -90.0, cont1_173),
			Spawnpoint(vector3(-2874.0, 470, 7312.3), 0.0, -90.0, cont1_173),
			Spawnpoint(vector3(-2874.0, 470, 6043.3), 0.0, -90.0, cont1_173),
			Spawnpoint(vector3(-2874.0, 470, 5516.3), 0.0, -90.0, cont1_173),
			Spawnpoint(vector3(-2874.0, 470, 5011.1), 0.0, -90.0, cont1_173),
			Spawnpoint(vector3(-1534.0, 470, 9366.3), 0.0, 90.0, cont1_173),
			Spawnpoint(vector3(-1534.0, 470, 8839.3), 0.0, 90.0, cont1_173),
			Spawnpoint(vector3(-1534.0, 470, 8333.9), 0.0, 90.0, cont1_173),
			Spawnpoint(vector3(-1534.0, 470, 7817.3), 0.0, 90.0, cont1_173),
			Spawnpoint(vector3(-1534.0, 470, 7312.3), 0.0, 90.0, cont1_173),
			Spawnpoint(vector3(-1534.0, 470, 6043.3), 0.0, 90.0, cont1_173),
			Spawnpoint(vector3(-1534.0, 470, 5516.3), 0.0, 90.0, cont1_173),
			Spawnpoint(vector3(-1534.0, 470, 5011.1), 0.0, 90.0, cont1_173)
		});

		Role@ Janitor = Role(ROLE_JANITOR, "Janitor", CATEGORY_STAFF, PlayerModel(CLASS_D_MODEL, {JANITOR_TEXTURE}), Color(150,113,0), "Evacuate the complex. Find salvation. Don't trust anyone.",
		{
			Spawnpoint(vector3(0.0, 78, 0.0), 0.0, 0.0, world.GetRoomByIdentifier(r_room2_js))
		}, {"Level 0 Key Card"});
		
		Role@ Scientist = Role(ROLE_SCIENTIST, "Scientist", CATEGORY_STAFF, 
		PlayerModel(CLASS_D_MODEL, 
		{
			SCIENTIST_1_TEXTURE, 
			SCIENTIST_2_TEXTURE, 
			SCIENTIST_3_TEXTURE, 
			SCIENTIST_4_TEXTURE, 
			SCIENTIST_5_TEXTURE, 
			SCIENTIST_6_TEXTURE, 
			SCIENTIST_7_TEXTURE
		}), Color(200,200,200), "Evacuate from the complex. Find salvation.",
		{ 
			Spawnpoint(vector3(frand(0.0, -400.0), 78, frand(-90.0, 90.0)), 0.0, frand(-180.0, 180.0), room3_storage),
			Spawnpoint(vector3(frand(0.0, -400.0), 78, frand(-90.0, 90.0)), 0.0, frand(-180.0, 180.0), room3_storage),
			Spawnpoint(vector3(frand(0.0, -400.0), 78, frand(-90.0, 90.0)), 0.0, frand(-180.0, 180.0), room3_storage),
			Spawnpoint(vector3(frand(0.0, -400.0), 78, frand(-90.0, 90.0)), 0.0, frand(-180.0, 180.0), room3_storage),
			Spawnpoint(vector3(frand(0.0, -400.0), 78, frand(-90.0, 90.0)), 0.0, frand(-180.0, 180.0), room3_storage),
			Spawnpoint(vector3(frand(0.0, -400.0), 78, frand(-90.0, 90.0)), 0.0, frand(-180.0, 180.0), room3_storage),
			Spawnpoint(vector3(frand(0.0, -400.0), 78, frand(-90.0, 90.0)), 0.0, frand(-180.0, 180.0), room3_storage),
			Spawnpoint(vector3(frand(0.0, -400.0), 78, frand(-90.0, 90.0)), 0.0, frand(-180.0, 180.0), room3_storage),
			Spawnpoint(vector3(frand(0.0, -400.0), 78, frand(-90.0, 90.0)), 0.0, frand(-180.0, 180.0), room3_storage)
		}, {"Level 1 Key Card"});

		Role@ Guard = Role(ROLE_GUARD, "Guard", CATEGORY_SECURITY, PlayerModel(GUARD_MODEL), Color(20, 20, 200), "Find and save Scientists. Arrest or neutralize Class D.",
		{ 
			Spawnpoint(vector3(frand(-478.0, 478), 78, -333.0), 0.0, 0.0, gate_b_entrance),
			Spawnpoint(vector3(frand(-478.0, 478), 78, -333.0), 0.0, 0.0, gate_b_entrance),
			Spawnpoint(vector3(frand(-478.0, 478), 78, -333.0), 0.0, 0.0, gate_b_entrance),
			Spawnpoint(vector3(frand(-478.0, 478), 78, -333.0), 0.0, 0.0, gate_b_entrance),
			Spawnpoint(vector3(frand(-478.0, 478), 78, -333.0), 0.0, 0.0, gate_b_entrance),
			Spawnpoint(vector3(frand(-478.0, 478), 78, -333.0), 0.0, 0.0, gate_b_entrance),
			Spawnpoint(vector3(frand(-478.0, 478), 78, -333.0), 0.0, 0.0, gate_b_entrance),
			Spawnpoint(vector3(frand(-478.0, 478), 78, -333.0), 0.0, 0.0, gate_b_entrance),
			Spawnpoint(vector3(frand(-478.0, 478), 78, -333.0), 0.0, 0.0, gate_b_entrance),
			Spawnpoint(vector3(frand(-478.0, 478), 78, -333.0), 0.0, 0.0, gate_b_entrance),
			Spawnpoint(vector3(frand(-478.0, 478), 78, -333.0), 0.0, 0.0, gate_b_entrance),
			Spawnpoint(vector3(frand(-478.0, 478), 78, -333.0), 0.0, 0.0, gate_b_entrance)
		}, {"P90", "Five-Seven", "Level 4 Key Card", "Radio Transceiver", "Compact First Aid Kit;Ballistic Helmet;Ballistic Vest;Handcuffs"});

		Role@ MTF = Role(ROLE_MTF, "Mobile Task Force Recruit", CATEGORY_SECURITY, PlayerModel(MTF_MODEL, {MTF_TEXTURE}), Color(20, 20, 200), "Find and save Scientists. Arrest or neutralize Class D.",
		{ 
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b)
		}, {"P90", "Five-Seven", "Level 4 Key Card", "Radio Transceiver", "Compact First Aid Kit;Ballistic Helmet;Ballistic Vest;Handcuffs;Ammo crate"});
		
		Role@ MTFMed = Role(ROLE_MTF_MEDIC, "Mobile Task Force Medic", CATEGORY_SECURITY, PlayerModel(MTF_MODEL, {MTF_MEDIC_TEXTURE}), Color(20, 20, 200), "Find and save Scientists. Arrest or neutralize Class D",
		{ 
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b)
		}, {"MP7", "Five-Seven", "Level 4 Key Card", "Radio Transceiver", "Ballistic Helmet;Ballistic Vest;Compact First Aid Kit;Compact First Aid Kit;Compact First Aid Kit;Compact First Aid Kit;Compact First Aid Kit;Ammo crate"});
		
		Role@ MTFSer = Role(ROLE_MTF_SERGEANT, "Mobile Task Force Sergeant", CATEGORY_SECURITY, PlayerModel(MTF_MODEL, {MTF_SERGEANT_TEXTURE}), Color(20, 20, 200), "Find and save Scientists. Arrest or neutralize Class D. Command your subordinates.",
		{ 
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b)
		}, {"M4A1", "Five-Seven", "Level 5 Key Card", "Radio Transceiver", "Compact First Aid Kit;Ballistic Helmet;Heavy Ballistic Vest;Handcuffs;Ammo crate"});
		
		Role@ MTFCom = Role(ROLE_MTF_COMMANDER, "Mobile Task Force Captain", CATEGORY_SECURITY, PlayerModel(MTF_MODEL, {MTF_COMMANDER_TEXTURE}), Color(20, 20, 200), "Find and save Scientists. Arrest or neutralize Class D. Command your subordinates.",
		{ 
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(4000.0, 4800.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b),
			Spawnpoint(vector3(frand(9300.0, 10000.0), 50, frand(-5300.0, -4600.0)), 0.0, 0.0, gate_a_b)
		}, {"M4A1", "Five-Seven", "Key Card Omni", "Radio Transceiver", "Compact First Aid Kit;Ballistic Helmet;Heavy Ballistic Vest;Handcuffs;Ammo crate"});
		
		Role@ Chaos = Role(ROLE_CHAOS, "Chaos Insurgency Recruit", CATEGORY_INMATE, PlayerModel(CHAOS_MODEL), Color(26, 64, 1), "Find and save Class D. Arrest or neutralize research staff.",
		{ 
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b)
		}, {"SR-556", "Glock", "Hacking Device", "Radio Transceiver", "Compact First Aid Kit;Ballistic Helmet;Ballistic Vest;Handcuffs;Ammo crate"});
		
		Role@ ChaosMed = Role(ROLE_CHAOS_MEDIC, "Chaos Insurgency Medic", CATEGORY_INMATE, PlayerModel(CHAOS_MODEL), Color(26, 64, 1), "Find and save Class D. Arrest or neutralize research staff. Heal your teammates",
		{ 
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b)
		}, {"MP5", "Glock", "Hacking Device", "Radio Transceiver", "Ballistic Helmet;Heavy Ballistic Vest;Compact First Aid Kit;Compact First Aid Kit;Compact First Aid Kit;Compact First Aid Kit;Ammo crate"});
		
		Role@ ChaosSer = Role(ROLE_CHAOS_GUNNER, "Chaos Insurgency Gunner", CATEGORY_INMATE, PlayerModel(CHAOS_MODEL), Color(26, 64, 1), "Find and save Class D. Arrest or neutralize research staff.",
		{ 
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b)
		}, {"M60", "Glock", "Hacking Device", "Radio Transceiver", "Compact First Aid Kit;Heavy Ballistic Helmet;Heavy Ballistic Vest;Handcuffs;Ammo crate"});
		
		Role@ ChaosCom = Role(ROLE_CHAOS_COMMANDER, "Chaos Insurgency Captain", CATEGORY_INMATE, PlayerModel(CHAOS_MODEL), Color(26, 64, 1), "Find and save Class D. Arrest or neutralize research staff. Command your subordinates.",
		{ 
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), 78, frand(10400.0, 11200.0)), 0.0, 180.0, gate_a_b)
		}, {"M4A1", "Glock", "Hacking Device", "Radio Transceiver", "Compact First Aid Kit;Ballistic Helmet;Heavy Ballistic Vest;Handcuffs;Ammo crate"});
		
		Role@ GOC = Role(ROLE_GOC, "Global Occult Coalition", CATEGORY_GOC, PlayerModel(GOC_MODEL, {GOC_TEXTURE}), Color(89, 148, 229), "Eliminate everyone in the complex.",
		{ 
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4000.0, -4500.0), -1185, frand(6300.0, 5300.0)), 0.0, -90.0, gate_a),
			Spawnpoint(vector3(frand(-4437.0, -4000.0), 1320, frand(6200.0, 6800.0)), 0.0, -90.0, gate_a_b),
			Spawnpoint(vector3(frand(-4437.0, -4000.0), 1320, frand(6200.0, 6800.0)), 0.0, -90.0, gate_a_b),
			Spawnpoint(vector3(frand(-4437.0, -4000.0), 1320, frand(6200.0, 6800.0)), 0.0, -90.0, gate_a_b),
			Spawnpoint(vector3(frand(-4437.0, -4000.0), 1320, frand(6200.0, 6800.0)), 0.0, -90.0, gate_a_b),
			Spawnpoint(vector3(frand(-4437.0, -4000.0), 1320, frand(6200.0, 6800.0)), 0.0, -90.0, gate_a_b),
			Spawnpoint(vector3(frand(-4437.0, -4000.0), 1320, frand(6200.0, 6800.0)), 0.0, -90.0, gate_a_b)
		}, {"M4A1", "M60", "Key Card Omni", "Radio Transceiver", "Handcuffs;Compact First Aid Kit;Compact First Aid Kit;Ballistic Helmet;Heavy Ballistic Vest;Ammo crate"});
		
		Role@ scp173 = Role(ROLE_SCP_173, "SCP-173", CATEGORY_ANOMALY, PlayerModel(SCP_173_MODEL), Color(200, 0, 0), "Kill everyone. Wait 45 seconds to start.",
		{
			Spawnpoint(vector3(0, 78, 0), 0.0, 0.0, cont1_173)
		}, {}, true, 0.0, 12000, 1, true);
		
		Role@ scp049 = Role(ROLE_SCP_049, "SCP-049", CATEGORY_ANOMALY, PlayerModel(SCP_049_MODEL), Color(200, 0, 0), "Cure everyone. Wait 45 seconds to start.",
		{
			Spawnpoint(vector3(0, 83, 597), 0.0, 0.0, world.GetRoomByIdentifier(r_cont2_049))
		}, {}, true, 0.0, 10000, 8, true);
		
		Role@ scp106 = Role(ROLE_SCP_106, "SCP-106", CATEGORY_ANOMALY, PlayerModel(SCP_106_MODEL), Color(200, 0, 0), "Kill everyone. Wait 45 seconds to start.",
		{
			Spawnpoint(vector3(-132, 83, -704), 0.0, 0.0, world.GetRoomByIdentifier(r_cont1_106))
		}, {}, true, 4.0, 8750, 1.5, true);
		
		Role@ scp939 = Role(ROLE_SCP_939, "SCP-939", CATEGORY_ANOMALY, PlayerModel(SCP_939_MODEL), Color(200, 0, 0), "Kill everyone. Wait 45 seconds to start.",
		{
			Spawnpoint(vector3(567.0, -5550.0, 5176.0), 0.0, 0.0, room3_storage),
			Spawnpoint(vector3(3980.0, -5550.0, -968.0), 0.0, 0.0, room3_storage),
			Spawnpoint(vector3(1083.0, -5550.0, 3023.0), 0.0, 0.0, room3_storage)
		}, {}, true, 1.3, 7500, 0.75, true);
		
		Role@ scp966 = Role(ROLE_SCP_966, "SCP-966", CATEGORY_ANOMALY, PlayerModel(SCP_966_MODEL), Color(200, 0, 0), "Kill everyone. Wait 45 seconds to start.",
		{
			Spawnpoint(vector3(0.0, 78.0, 512.0), 0.0, 0.0, cont3_966),
			Spawnpoint(vector3(0.0, 78.0, 0.0), 0.0, 0.0, cont3_966)
		}, {}, true, 1.0, 6250, 0.75, true);
		
		Role@ scp096 = Role(ROLE_SCP_096, "SCP-096", CATEGORY_ANOMALY, PlayerModel(SCP_096_MODEL), Color(200, 0, 0), "Kill everyone. Wait 45 seconds to start.",
		{
			Spawnpoint(vector3(-1368, 78.0, 368), 0.0, 0.0, room2_servers_hcz)
		}, {}, true, 0.01, 5600, 0.75, true);
		
		Role@ scp860 = Role(ROLE_SCP_860, "SCP-860-2", CATEGORY_ANOMALY, PlayerModel(SCP_860_MODEL), Color(200, 0, 0), "Kill everyone. Wait 45 seconds to start.",
		{
			Spawnpoint(vector3(0, 80.0, 0), 0.0, 0.0, world.GetRoomByIdentifier(r_cont2_860_1))
		}, {}, true, 1.2, 6250, 0.75, true);
		
		Role@ scp0492 = Role(ROLE_SCP_0492, "SCP-049-2", CATEGORY_ANOMALY, PlayerModel(ZOMBIE_MODEL, {CLASS_D_ZOMBIE_TEXTURE}), Color(200, 0, 0), "Kill everyone. Listen to SCP-049", {}, {}, false, 1.0, 250, 0.75, false);
		Role@ scp0492_guard = Role(ROLE_SCP_0492_GUARD, "SCP-049-2", CATEGORY_ANOMALY, PlayerModel(ZOMBIE_GUARD_MODEL), Color(200, 0, 0), "Kill everyone. Listen to SCP-049", {}, {}, false, 1.0, 250, 0.75, false);
		Role@ scp035 = Role(ROLE_SCP_035, "SCP-035", CATEGORY_ANOMALY, PlayerModel(), Color(200, 0, 0), "Kill everyone.", {}, {}, false, 1.0, 500, 0.0, false);
		
		Role@ scp999 = Role(ROLE_SCP_999, "SCP-999", CATEGORY_ANOMALYSTALEMATE, PlayerModel(SCP_999_MODEL), Color(200, 50, 50), "Heal whoever you want.",
		{
			Spawnpoint(vector3(0, 80.0, 0), 0.0, 0.0, world.GetRoomByIdentifier(r_room2_office))
		}, {}, false, 0.0, 3750, 8.0, true);
		
		Role@ Ghost = Role(ROLE_GHOST, "Ghost", CATEGORY_STALEMATE, PlayerModel(CLASS_D_MODEL), Color(212,113,0), "", {Spawnpoint(vector3(-2874.0, 470, 9366.3), 0.0, -90.0, cont1_173)}, {}, false, 1.0, 20000, 0.0, true);
		
		ClassD.SetGenerationFactor(8);
		Janitor.SetGenerationFactor(1.9);
		Scientist.SetGenerationFactor(4);
		Guard.SetGenerationFactor(2.1);
		
		scp999.SetAdditiveSingles(2);
		
		scp049.AddIdleSound("SFX\\SCP\\049\\Searching0.ogg");
		scp049.AddIdleSound("SFX\\SCP\\049\\Searching0.ogg");
		scp049.AddIdleSound("SFX\\SCP\\049\\Searching0.ogg");
		scp049.AddIdleSound("SFX\\SCP\\049\\Searching0.ogg");
		scp049.AddIdleSound("SFX\\SCP\\049\\Searching0.ogg");
		scp049.AddIdleSound("SFX\\SCP\\049\\Searching0.ogg");
		scp049.AddIdleSound("SFX\\SCP\\049\\Searching0.ogg");
		scp049.AddIdleSound("SFX\\SCP\\049\\Searching0.ogg");
		scp049.SetIdleSoundTime(25.0);

		scp0492.AddIdleSound("SFX\\SCP\\049_2\\Breath.ogg");
		scp0492.SetIdleSoundTime(30.0);
		
		scp0492_guard.AddIdleSound("SFX\\SCP\\049_2\\Breath.ogg");
		scp0492_guard.SetIdleSoundTime(30.0);
		
		scp096.AddIdleSound("SFX\\Music\\096.ogg");
		scp096.SetIdleSoundTime(50.0);
		
		scp966.AddIdleSound("SFX\\SCP\\966\\Idle0.ogg");
		scp966.AddIdleSound("SFX\\SCP\\966\\Idle1.ogg");
		scp966.AddIdleSound("SFX\\SCP\\966\\Idle2.ogg");
		scp966.SetIdleSoundTime(25.0);

		scp939.AddIdleSound("SFX\\SCP\\939\\0Lure0.ogg");
		scp939.AddIdleSound("SFX\\SCP\\939\\0Lure1.ogg");
		scp939.AddIdleSound("SFX\\SCP\\939\\0Lure2.ogg");
		scp939.AddIdleSound("SFX\\SCP\\939\\0Lure3.ogg");
		scp939.AddIdleSound("SFX\\SCP\\939\\0Lure4.ogg");
		scp939.AddIdleSound("SFX\\SCP\\939\\0Lure5.ogg");
		scp939.AddIdleSound("SFX\\SCP\\939\\0Lure6.ogg");
		scp939.AddIdleSound("SFX\\SCP\\939\\0Lure7.ogg");
		scp939.AddIdleSound("SFX\\SCP\\939\\0Lure8.ogg");
		scp939.AddIdleSound("SFX\\SCP\\939\\0Lure9.ogg");
		scp939.SetIdleSoundTime(25.0);

		scp106.AddIdleSound("SFX\\SCP\\106\\Corrosion0.ogg");
		scp106.AddIdleSound("SFX\\SCP\\106\\Corrosion1.ogg");
		scp106.AddIdleSound("SFX\\SCP\\106\\Corrosion2.ogg");
		scp106.SetIdleSoundTime(7.0);
		
		scp173.AddIdleSound("SFX\\SCP\\173\\Rattle0.ogg");
		scp173.AddIdleSound("SFX\\SCP\\173\\Rattle1.ogg");
		scp173.AddIdleSound("SFX\\SCP\\173\\Rattle2.ogg");
		scp173.SetIdleSoundTime(7.0);
		
		MTF.SetTerminationAnnouncement("SFX\\Character\\MTF\\AnnouncLostUnknown.ogg");
		MTFMed.SetTerminationAnnouncement("SFX\\Character\\MTF\\AnnouncLostUnknown.ogg");
		MTFCom.SetTerminationAnnouncement("SFX\\Character\\MTF\\AnnouncLostUnknown.ogg");
		MTFSer.SetTerminationAnnouncement("SFX\\Character\\MTF\\AnnouncLostUnknown.ogg");
		scp173.SetTerminationAnnouncement("SFX\\Character\\MTF\\Announc173ContainCI.ogg");
		scp049.SetTerminationAnnouncement("SFX\\Character\\MTF\\Announc049ContainCI.ogg");
		scp106.SetTerminationAnnouncement("SFX\\Character\\MTF\\Announc106ContainCI.ogg");
		scp096.SetTerminationAnnouncement("SFX\\Character\\MTF\\Announc096ContainCI.ogg");
		
		Guard.SetRadio(rand(10000, 80000));
		MTF.SetRadio(Guard.radioChannel);
		MTFCom.SetRadio(Guard.radioChannel);
		MTFMed.SetRadio(Guard.radioChannel);
		MTFSer.SetRadio(Guard.radioChannel);
		
		Chaos.SetRadio(rand(10000, 80000));
		ChaosCom.SetRadio(Chaos.radioChannel);
		ChaosSer.SetRadio(Chaos.radioChannel);
		ChaosMed.SetRadio(Chaos.radioChannel);
		
		GOC.SetRadio(rand(10000, 80000));
		
		Add(Spectator);
		Add(Guard);
		Add(Scientist);
		Add(Janitor);
		Add(ClassD);
		Add(MTF);
		Add(MTFMed);
		Add(MTFSer);
		Add(MTFCom);
		Add(Chaos);
		Add(ChaosMed);
		Add(ChaosSer);
		Add(ChaosCom);
		Add(scp173);
		Add(scp049);
		Add(scp106);
		Add(scp939);
		Add(scp966);
		Add(scp096);
		Add(scp0492);
		Add(scp0492_guard);
		Add(scp035);
		Add(scp999);
		Add(scp860);
		Add(GOC);
		Add(Ghost);
		
		for(int i = 0; i < roles.size(); i++) {
			for(int t = 0; t < roles.size(); t++) {
				if((roles[t].category == roles[i].category || roles[t].category == CATEGORY_STALEMATE)
				|| (roles[i].category == CATEGORY_ANOMALY && roles[t].category == CATEGORY_ANOMALYSTALEMATE)) roles[i].SetFriend(roles[t]);
			
				if(roles[i].name.findFirst("Chaos Insurgency") >= 0 && roles[t].name.findFirst("Chaos Insurgency") >= 0) roles[i].SetRelative(roles[t]);
				if(roles[i].name.findFirst("Mobile Task Force") >= 0 && roles[t].name.findFirst("Mobile Task Force") >= 0) roles[i].SetRelative(roles[t]);
			}
		}
		
		for(int i = 0; i < roles.size(); i++) {
			if(roles[i].category == CATEGORY_STAFF) {
				for(int t = 0; t < roles.size(); t++) {
					if(roles[t].category == CATEGORY_SECURITY) roles[i].SetFriend(roles[t]);
				}
			}
		}
		
		AddCategory(Category(CATEGORY_STALEMATE, "Stalemate", Color(200, 200, 200)));
		AddCategory(Category(CATEGORY_INMATE, "Class D and " + Color(26, 64, 1).GetFormat() + "Chaos", Color(212, 113, 0)));
		AddCategory(Category(CATEGORY_STAFF, "Researchers", Color(200, 200, 200)));
		AddCategory(Category(CATEGORY_SECURITY, "Security", Color(47, 80, 255)));
		AddCategory(Category(CATEGORY_ANOMALY, "SCPs", Color(200, 0, 0)));
		AddCategory(Category(CATEGORY_GOC, "GOC", Color(89, 148, 229)));
		
		AddEscapeSection(EscapeSection(vector3(2678.9, -753.2, 5404.0), gate_b, CATEGORY_STAFF, {Scientist, ClassD, Janitor}, MTF));
		AddEscapeSection(EscapeSection(vector3(-4062.9, -1191.2, -51.0), gate_a, CATEGORY_INMATE, {Scientist, ClassD, Janitor}, Chaos));
		
		AddEscapeSection(EscapeSection(vector3(7940.9, -753.2, 5404.0), gate_a_b, CATEGORY_STAFF, {Scientist, ClassD, Janitor}, MTF));
		AddEscapeSection(EscapeSection(vector3(2013.9, 78.2, 10645.2), gate_a_b, CATEGORY_INMATE, {Scientist, ClassD, Janitor}, Chaos));
	}

	void Assign(array<Player> players)
	{
		if(players.empty()) return;
		
		int targetSingleCount = 0;
		float rolesDivisor = 0.0;
		float multiplier = 0.0;
		int singlesCount = 0;
		array<Role@> singleRoles;
		array<Role@> instancesRoles;
		
		for(int i = 0; i < roles.size(); i++) {
			if(!roles[i].single) rolesDivisor += roles[i].GetGenerationFactor();
			else singleRoles.push_back(roles[i]);
		}
		
		// Count roles count by players count
		targetSingleCount = round(max(float(players.size()) / 7.9, 1.0)); // Must be minimum 1 single role
		multiplier = float(players.size()) / rolesDivisor;

		while(targetSingleCount > 0 && players.size() > 0 && singleRoles.size() > 0) // Assigning single roles
		{
			int randomSingle = rand(0, singleRoles.size() - 1);
			int randomIndex = rand(0, players.size() - 1);
			SetPlayerRole(players[randomIndex], singleRoles[randomSingle]);
			players.removeAt(randomIndex);
			
			for(int i = 0; i < singleRoles[randomSingle].GetGenerationFactor(); i++) {
				instancesRoles.push_back(singleRoles[randomSingle]);
			}
			
			singleRoles.removeAt(randomSingle);
			targetSingleCount--;
			
			singlesCount++;
		}
		
		while(targetSingleCount > 0 && players.size() > 0 && instancesRoles.size() > 0) // Assigning instances of single roles if count remains
		{
			int randomInstance = rand(0, instancesRoles.size() - 1);
			int randomIndex = rand(0, players.size() - 1);
			SetPlayerRole(players[randomIndex], instancesRoles[randomInstance]);
			players.removeAt(randomIndex);
			instancesRoles.removeAt(randomInstance);
			targetSingleCount--;
		}
		
		for(int i = 0; i < roles.size() && players.size() > 0; i++) // Assigning additive from single roles
		{
			if(roles[i].additiveSingles > 0 && roles[i].additiveSingles < singlesCount)
			{
				int randomIndex = rand(0, players.size() - 1);
				SetPlayerRole(players[randomIndex], roles[i]);
				players.removeAt(randomIndex);
			}
		}
		
		for(int i = 0; i < roles.size() && players.size() > 0; i++) // Assigning non-single roles
		{
			if(!roles[i].single) {
				int needCount = round(roles[i].GetGenerationFactor() * multiplier);
				for(int c = 0; c < needCount && players.size() > 0; c++) {
					int randomIndex = rand(0, players.size() - 1);
					SetPlayerRole(players[randomIndex], roles[i]);
					players.removeAt(randomIndex);
				}
			}
		}
		
		// The remaining becomes Class D
		Role@ ClassD = Roles::Find(ROLE_CLASS_D);
		if(@ClassD != null) 
		{
			for(int p = 0; p < players.size(); p++) SetPlayerRole(players[p], ClassD);
		}
	}

	void Add(Role@ role)
	{
		roles.push_back(role);
	}
	
	void AddEscapeSection(EscapeSection@ sec)
	{
		escapeSec.push_back(sec);
	}
	
	void AddCategory(Category@ c)
	{
		categories.push_back(c);
	}
	
	Role@ Find(int roleid)
	{
		for(int i = 0; i < roles.size(); i++) {
			if(roles[i].roleid == roleid) return roles[i];
		}
		return null;
	}
	
	Role@ GetRole(int index)
	{
		return roles.size() > index ? @roles[index] : @null;
	}

	Category@ GetCategory(int c)
	{
		for(int i = 0; i < categories.size(); i++) if(categories[i].identifier == c) return categories[i];
		return null;
	}
	
	array<EscapeSection@>& GetEscapeSections()
	{
		return escapeSec;
	}
	
	void ClearEscapeSections()
	{
		escapeSec.clear();
	}

	void ClearCategories()
	{
		categories.clear();
	}

	void Clear()
	{
		roles.clear();
	}
}