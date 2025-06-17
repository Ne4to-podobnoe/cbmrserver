const int MINIMUM_PLAYERS 	= 4;
const int LOBBY_START_TIMER = 120;
const int ROUND_TIME		= 2100;
const int MTF_TIMER			= 400;
const int SCP_TIMEOUT		= 45;

GUIElement[] LobbyGUI(10);
GUIElement[] EndRoundGUI(10);
GUIElement RoundTime;

int[] CategoryEscaped;
int[] CuffedCategoryEscaped;
int wonTimer;
Object IntercomButton;
Object WarheadsButton;
Object Mask035;
Object Recontainer;
Object RecontainButton;
Object RecontainDoor;
Door LobbyElevator1;
Door LobbyElevator2;
int WarheadsTimer;
bool ArriveSide;
int recontainState;

class Round_Settings
{
	Round_Settings()
	{
		
	}
	~Round_Settings()
	{
		
	}
	
	bool friendlyfirePunish;
	bool friendlyfire;
}

namespace Round
{
	Round_Settings@ roundSettings = Round_Settings();
	
	bool IsRoundStarted = false;
	int RoundTimer = 0;
	int WaveTimer = 0;
	bool WarheadsEnabled;
	bool isRoundEnded;
	bool WarheadsExploded;
	
	Round_Settings@ GetSettings()
	{
		return roundSettings;
	}
	
	void LoadSettings()
	{
		Round::GetSettings().friendlyfire = false;
		Round::GetSettings().friendlyfirePunish = true;
	}
	
	void Create()
	{
		if(IntercomButton != NULL) return;
		
		Room r = world.GetRoomByIdentifier(r_room2c_ec);
		
		if(r != NULL) {
			IntercomButton = world.CreateObject(81, r);
			IntercomButton.SetTouchable(true);
			Entity button = IntercomButton.GetEntity();
			button.SetParent(r.GetEntity());
			button.SetScale(0.04, 0.04, 0.04, true);
			button.SetPosition(-236.0, 1105.5, 402.543);
			button.SetRotation(0, -90, 0);
		}
		
		r = world.GetRoomByIdentifier(r_gate_b);
		
		if(r != NULL) {
			WarheadsButton = world.CreateObject(81, r);
			WarheadsButton.SetTouchable(true);
			Entity button = WarheadsButton.GetEntity();
			button.SetParent(r.GetEntity());
			button.SetScale(0.04, 0.04, 0.04, true);
			button.SetPosition(4020.0, -723.605, 5835.86);
			button.SetRotation(0, -90, 0);
		}
		else
		{
			r = world.GetRoomByIdentifier(r_gate_a_b);
			if(r != NULL) {
				WarheadsButton = world.CreateObject(81, r);
				WarheadsButton.SetTouchable(true);
				Entity button = WarheadsButton.GetEntity();
				button.SetParent(r.GetEntity());
				button.SetScale(0.04, 0.04, 0.04, true);
				button.SetPosition(9322.0, -723.605, 5835.86);
				button.SetRotation(0, -90, 0);
			}
		}
		
		r = world.GetRoomByIdentifier(r_cont1_106);
		if(r != NULL) {
			Recontainer = world.CreateObject(256, r);
			Entity recon = Recontainer.GetEntity();
			recon.SetParent(r.GetEntity());
			recon.SetPosition(-1370.0, -8100.0, 2664.86);
			recon.SetRotation(0, -90.0, 0);
			recon.SetScale(1.0, 1.0, 1.0);
			
			RecontainButton = world.CreateObject(81, r);
			RecontainButton.SetTouchable(true);
			Entity recbut = RecontainButton.GetEntity();
			recbut.SetParent(r.GetEntity());
			recbut.SetPosition(-1393.5, -7916.7, 2777.91);
			recbut.SetRotation(0, 150.0, 0);
			recbut.SetScale(0.03, 0.03, 0.03, true);
			
			RecontainDoor = world.CreateObject(102, r);
			RecontainDoor.SetTexture(110);
			Entity recdoor = RecontainDoor.GetEntity();
			recdoor.SetParent(r.GetEntity());
			recdoor.SetPosition(-1366.28, -8100, 2667.61);
			recdoor.SetRotation(0, -90.0, 0);
			recdoor.SetScale(14.08, 14.08, 14.08);
		}
		
		r = world.GetRoomByIdentifier(r_cont2_860_1);
		if(r != NULL) {
			float x, y, z;
			TFormRoom(r, 744, 0, 640, x, y, z);
			vector3 door1(x, y, z);
			TFormRoom(r, 744, 0, -640, x, y, z);
			vector3 door2(x, y, z);
			
			for(int i = 0; i < MAX_DOORS; i++) {
				Door d = world.GetDoor(i);
				if(d != NULL) {
					Entity ent = d.GetEntity();
					if(DistanceSquared(door1, vector3(ent.PositionX(true), ent.PositionY(true), ent.PositionZ(true))) < 10.0 
					|| DistanceSquared(door2, vector3(ent.PositionX(true), ent.PositionY(true), ent.PositionZ(true))) < 10.0) {
						d.SetOpen(true);
						d.SetLockState(1);
					}
				}
			}
		}
		
		Mask035 = NULL;
	}

	void Update()
	{
		if(IsStarted())
		{
			UpdateWaves();
			UpdateWarheads();
			UpdateTime();
			OverTimer();
		}
	}
	
	void Start()
	{
		if(!IsStarted()) {
			Roles::Assign(connPlayers);
			
			Room r = world.GetRoomByIdentifier(r_cont1_035);
			if(r != NULL) {
				Door d = r.GetDoor(1);
				if(d != NULL) d.SetLockState(0);
				
				if(connPlayers.size() >= 12) // Mask 035 spawn
				{
					Mask035 = world.CreateObject(227, r);
					Mask035.SetTouchable(true);
					Entity mask = Mask035.GetEntity();
					mask.SetParent(r.GetEntity());
					mask.SetScale(0.0143, 0.0143, 0.0143, true);
					mask.SetPosition(-272.798, 152, 311);
					mask.SetRotation(90, 0, 0);
				}
			}

			if(RecontainDoor != NULL) {
				Entity recdoor = RecontainDoor.GetEntity();
				recdoor.SetPosition(-1366.28, -7700, 2667.61);
			}
			
			SetTimer(ROUND_TIME);
			IsRoundStarted = true;
			recontainState = 0;
			
			LobbyGUI[0].Hide();
			LobbyGUI[1].Hide();
			
			SetWaveTimer(MTF_TIMER);
			
			CategoryEscaped.clear();
			CuffedCategoryEscaped.clear();
			CategoryEscaped.resize(MAX_POSSIBLE_CATEGORIES);
			CuffedCategoryEscaped.resize(MAX_POSSIBLE_CATEGORIES);
		}
	}

	void Reload()
	{
		if(IsStarted()) {
			for(int i = 0; i < connPlayers.size(); i++) SetPlayerRole(connPlayers[i], null);
			
			for(int i = 0; i < MAX_OBJECTS; i++) {
				if(world.GetObject(i) != NULL) world.GetObject(i).Remove();
			}
			
			Lobby::Load();
		}
	}

	void End(bool restart = true)
	{
		if(!IsStarted()) return;
		
		if(EndRoundGUI[0] != NULL) {
			EndRoundGUI[0].Remove();
			EndRoundGUI[0] = NULL;
		}
		
		if(EndRoundGUI[1] != NULL) {
			EndRoundGUI[1].Remove();
			EndRoundGUI[1] = NULL;
		}
		
		ExplodeWarheads(false);
		SetWarheadsTimer(0);
		EnableWarheads(false);
		IsRoundStarted = false;
		isRoundEnded = false;
		
		if(restart) 
		{
			server.Restart();
		}
	}

	void UpdateWaves()
	{
		SetWaveTimer(GetWaveTimer() - 1);
		if(GetWaveTimer() == 0) SpawnWave();
	}

	void UpdateWarheads()
	{
		SetWarheadsTimer(GetWarheadsTimer() - 1);
		if(IsWarheadsEnabled()) {
			if(GetWarheadsTimer() == 10) {
				Event event = world.GetEventByIdentifier(e_room2_nuke);
				if(event != NULL && event.GetState() != 1.0) {
					audio.PlaySound("SFX\\Ending\\GateB\\AlphaWarheadsFail.ogg");
					EnableWarheads(false);
					return;
				}
				
				ExplodeWarheads(true);
			}
			else if(GetWarheadsTimer() == 0) End();
		}
	}

	void ExplodeWarheads(bool explode)
	{
		if(!IsWarheadsExploded() && explode) {
			for(int i = 0; i < connPlayers.size(); i++) {
				Player dest = connPlayers[i];
				dest.Explode(dest.GetRoom().GetIdentifier() == r_gate_a || dest.GetRoom().GetIdentifier() == r_gate_b || dest.GetRoom().GetIdentifier() == r_gate_a_b);
			}
		}
		
		WarheadsExploded = explode;
	}
				
	int CheckOver()
	{
		int MTFUnits = 0, 
			Guards = 0, 
			Scientists = 0, 
			SCPs = 0, 
			Chaoses = 0, 
			ClassDs = 0,
			GOCs = 0;
		
		for(int i = 0; i < connPlayers.size(); i++) 
		{
			Player dest = connPlayers[i];
			info_Player@ info = GetPlayerInfo(dest);
			if(@info.pClass != null) {
				if(info.pClass.category == CATEGORY_ANOMALY) SCPs++;
				else
				{
					switch(info.pClass.roleid) 
					{
						case ROLE_MTF: case ROLE_MTF_COMMANDER: case ROLE_MTF_MEDIC: case ROLE_MTF_SERGEANT: { MTFUnits++; break; }
						case ROLE_GUARD: { Guards++; break; }
						case ROLE_SCIENTIST: case ROLE_JANITOR: { Scientists++; break; }
						case ROLE_CHAOS: case ROLE_CHAOS_COMMANDER: case ROLE_CHAOS_GUNNER: case ROLE_CHAOS_MEDIC: { Chaoses++; break; }
						case ROLE_CLASS_D: { ClassDs++; break; }
						case ROLE_GOC: { GOCs++; break; }
					}
				}
			}
		}

		if(MTFUnits > 0 || Guards > 0 || Scientists > 0) 
		{
			if(SCPs > 0 || Chaoses > 0 || ClassDs > 0) return 0;
			else if(CuffedCategoryEscaped[CATEGORY_INMATE] > 0 || CategoryEscaped[CATEGORY_STAFF] > 0) return CATEGORY_SECURITY;
			else return CATEGORY_STALEMATE;
		}
		else 
		{
			if(SCPs > 0) 
			{
				if(ClassDs > 0) return 0;
				else 
				{
					if(CategoryEscaped[CATEGORY_INMATE] > 0 || CuffedCategoryEscaped[CATEGORY_STAFF] > 0) return CATEGORY_INMATE;
					else return CATEGORY_ANOMALY;
				}
			}
			else if(GOCs > 0 && Chaoses == 0 && ClassDs == 0) return CATEGORY_GOC;
			else {
				if(CategoryEscaped[CATEGORY_INMATE] > 0 || CuffedCategoryEscaped[CATEGORY_STAFF] > 0) return CATEGORY_INMATE;
				else return CATEGORY_ANOMALY;
			}
		}
	}

	void OverTimer()
	{
		if(!IsStarted() || IsWarheadsExploded()) return;
		
		if(isRoundEnded) 
		{
			if(GetTimer() == 10)
			{
				Event event = world.GetEventByIdentifier(e_room2_nuke);
				if(event != NULL && event.GetState() != 1.0) {
					audio.PlaySound("SFX\\Ending\\GateB\\AlphaWarheadsFail.ogg");
					return;
				}
				
				for(int i = 0; i < connPlayers.size(); i++) {
					Player dest = connPlayers[i];
					dest.Explode(dest.GetRoom().GetIdentifier() == r_gate_a || dest.GetRoom().GetIdentifier() == r_gate_b || dest.GetRoom().GetIdentifier() == r_gate_a_b);
				}
			}
			else if(GetTimer() == 0) End();
		}
		else 
		{
			int categoryWon = CheckOver();
			if(categoryWon > 0 || GetTimer() < 1) 
			{
				EndRoundGUI[0] = graphics.CreateText(NULL, 8, "THE ROUND HAS FINISHED", 0.5, 0.15, true);
				if(categoryWon > 0) {
					Category@ wonCategory = Roles::GetCategory(categoryWon);
					EndRoundGUI[1] = graphics.CreateText(NULL, 8, wonCategory.color.GetFormat() + wonCategory.name + (wonCategory.name == "Stalemate" ? "" : " &r[]WON!"), 0.5, 0.2, true);
				}
				
				SetTimer(70);
				isRoundEnded = true;
				
				if(!IsWarheadsEnabled()) { // Can't enable if warheads already controls by usual warheads
					audio.PlaySound("SFX\\Ending\\GateB\\DetonatingAlphaWarheads.ogg");
					CreateTimer(SirenUpdate, 10000, false);
				}
				
				Round::GetSettings().friendlyfire = true;
				Round::GetSettings().friendlyfirePunish = false;
			}
		}
	}

	void SirenUpdate()
	{
		if(!IsStarted() || IsWarheadsEnabled()) return;
		audio.PlaySound("SFX\\Ending\\GateB\\Siren.ogg");
		CreateTimer(SirenUpdate, 11000, false);
	}

	void WarheadsSirenUpdate()
	{
		if(!IsWarheadsEnabled()) return;
		audio.PlaySound("SFX\\Ending\\GateB\\Siren.ogg");
		CreateTimer(WarheadsSirenUpdate, 11000, false);
	}

	void UpdateTime()
	{
		SetTimer(GetTimer() - 1);
		
		int TargetTimer = IsWarheadsEnabled() ? GetWarheadsTimer() : GetTimer();

		RoundTime.SetText(ConvertIntToTime(TargetTimer));
	}

	void SpawnWave()
	{
		array<Player> players;
		for(int i = 0; i < PlayersInfo.size(); i++) {
			if(@PlayersInfo[i] != null && @PlayersInfo[i].pClass != null && PlayersInfo[i].pClass.roleid == 0) players.push_back(PlayersInfo[i].player);
		}
		
		int size = players.size();
		
		if(size > 0) {
			server.Console("doorcontrol true");
			
			Event ev = world.GetEventByIdentifier(e_gate_a_entrance);
			if(ev != NULL) ev.SetState3(3.0);
			ev =  world.GetEventByIdentifier(e_gate_b_entrance);
			if(ev != NULL) ev.SetState3(3.0);
			
			ev =  world.GetEventByIdentifier(e_room2c_ec);
			if(ev != NULL) ev.Remove();
			
			array<Role@> assigners;
			
			if(ArriveSide) assigners = { Roles::Find(ROLE_CHAOS_GUNNER), Roles::Find(ROLE_CHAOS_MEDIC), Roles::Find(ROLE_CHAOS) };
			else assigners = { Roles::Find(ROLE_MTF_COMMANDER), Roles::Find(ROLE_MTF_SERGEANT), Roles::Find(ROLE_MTF_MEDIC), Roles::Find(ROLE_MTF) };
			
			int halfCount = 15;
			
			if(size > 4 && rand(0, 100) <= 20) // GOC Spawn
			{
				assigners = { Roles::Find(ROLE_GOC) };
				halfCount = int(max(connPlayers.size() / 6, 4));
				audio.PlaySound("SFX\\Character\\MTF\\AnnouncGOC.ogg");
			}
			else {
				audio.PlaySound(ArriveSide ? "SFX\\Character\\MTF\\AnnouncCI.ogg" : "SFX\\Character\\MTF\\AnnouncEnter.ogg");
				ArriveSide = !ArriveSide;
			}
			while(halfCount > 0 && players.size() > 0) 
			{
				int randomIndex = rand(0, players.size() - 1);
				
				SetPlayerRole(players[randomIndex], assigners[0]);
				if(assigners.size() > 1) assigners.removeAt(0); // leave latest usual role
				
				players.removeAt(randomIndex);
				halfCount --;
			}

			SetWaveTimer(rand(MTF_TIMER - 120, MTF_TIMER + 120));
		}
	}

	void CreateItemPoint(array<Items>@ items, Room r, vector3 pos, string itemName)
	{
		if(r == NULL) return;
		
		TFormRoom(r, pos.x, pos.y, pos.z, pos.x, pos.y, pos.z);
		
		for(int i = 0; i < items.size(); i++)
		{
			Items item = items[i];
			if(item == NULL) continue;
			Entity e = item.GetEntity();
			if(DistanceSquared(vector3(e.PositionX(), e.PositionY(), e.PositionZ()), pos) <= 6.0) 
			{
				world.CreateItem(itemName, true, e.PositionX(), e.PositionY(), e.PositionZ());
				item.Remove();
				items.removeAt(i);
				return;
			}
		}
		
		world.CreateItem(itemName, true, pos.x, pos.y, pos.z);
	}

	void SpawnItems()
	{
		array<Items>@ items = array<Items>();
		for(int i = 1; i <= MAX_ITEMS; i++) {
			if(world.GetItem(i) != NULL) items.push_back(world.GetItem(i));
		}
		
		// LCZ
		
		bool has914 = (world.GetRoomByIdentifier(r_cont1_914) != NULL);
		
		CreateItemPoint(items, world.GetRoomByIdentifier(r_cont2_427_714_860_1025), vector3(-607, 77.3, 633.0), has914 ? "Level 1 Key Card" : "Level 3 Key Card");
		CreateItemPoint(items, world.GetRoomByIdentifier(r_room2_closets), vector3(752.8, 121.1, 526.3), "Compact First Aid Kit");
		CreateItemPoint(items, world.GetRoomByIdentifier(r_room2_closets), vector3(737.8, 228.4, 764.5), has914 ? "Level 1 Key Card" : "Level 3 Key Card");
		CreateItemPoint(items, world.GetRoomByIdentifier(r_cont1_914), vector3(541.3, 188.7, 130.1), "Compact First Aid Kit");
		CreateItemPoint(items, world.GetRoomByIdentifier(r_cont2_500_1499), vector3(-653.0, 168.4, -766.7), has914 ? "Level 1 Key Card" : "Level 3 Key Card");
		CreateItemPoint(items, world.GetRoomByIdentifier(r_cont1_205), vector3(206.0, 190.0, 180), has914 ? "Level 1 Key Card" : "Level 2 Key Card");
		CreateItemPoint(items, world.GetRoomByIdentifier(r_cont1_205), vector3(-975.0, -15.0, 650), "Level 3 Key Card");
		
		CreateItemPoint(items, world.GetRoomByIdentifier(r_room1_storage), vector3(192.0, 96.0, 461), has914 ? "Compact First Aid Kit" : "Level 3 Key Card");
		CreateItemPoint(items, world.GetRoomByIdentifier(r_room1_storage), vector3(192.0, 96.0, -224), rand(0, 10) == 0 ? "Glock" : "Compact First Aid Kit");
		CreateItemPoint(items, world.GetRoomByIdentifier(r_room1_storage), vector3(192.0, 192.0, 110), "Compact First Aid Kit");
		CreateItemPoint(items, world.GetRoomByIdentifier(r_room2_sl), vector3(841.0, 640.0, -25.0), "Glock");
		
		// HCZ
		CreateItemPoint(items, world.GetRoomByIdentifier(r_room2_shaft), vector3(1930.0, 225.0, 128), "Glock");
		if(rand(10) == 0) CreateItemPoint(items, world.GetRoomByIdentifier(r_room2_shaft), vector3(996.0, 160.0, -102), "Level 4 Key Card");
		CreateItemPoint(items, world.GetRoomByIdentifier(r_room2_2_ez), vector3(800.0, -48.0, 368), rand(0, 1) == 0 ? "MP5" : "KRISS Vector");
		CreateItemPoint(items, world.GetRoomByIdentifier(r_cont2c_096), vector3(-1169.0, -563.0, 721), rand(0, 3) == 0 ? "Level 3 Key Card" : "Remington");
		CreateItemPoint(items, world.GetRoomByIdentifier(r_cont2c_096), vector3(14.0, -390, 1437), rand(0, 2) == 0 ? "Level 4 Key Card" : (rand(0, 1) == 0 ? "MP5" : "KRISS Vector"));
		
		world.RaycastItems();
	}
	
	bool IsStarted()
	{
		return IsRoundStarted;
	}
	
	bool IsWarheadsExploded()
	{
		return WarheadsExploded;
	}
	
	bool IsWarheadsEnabled()
	{
		return WarheadsEnabled;
	}
	
	bool EnableWarheads(bool enable, int timer = 90)
	{
		if(isRoundEnded && enable) return false; // Can't start usual warheads bcs end round control its warheads
		if(IsWarheadsExploded()) return false;
		
		WarheadsEnabled = enable;
		SetWarheadsTimer(timer);
		
		if(WarheadsEnabled) {
			audio.PlaySound("SFX\\Ending\\GateB\\DetonatingAlphaWarheads.ogg");
			CreateTimer(WarheadsSirenUpdate, 10000, false);
		}
		
		return true;
	}
	
	int GetWarheadsTimer()
	{
		return WarheadsTimer;
	}
	
	void SetWarheadsTimer(int time)
	{
		WarheadsTimer = time;
		if(WarheadsTimer < 0) WarheadsTimer = 0;
	}
	
	void SetWaveTimer(int time)
	{
		WaveTimer = time;
		if(WaveTimer < 0) WaveTimer = 0;
	}
	
	int GetWaveTimer()
	{
		return WaveTimer;
	}
	
	int GetTimer()
	{
		return RoundTimer;
	}
	
	void SetTimer(int time)
	{
		RoundTimer = time;
		if(RoundTimer < 0) RoundTimer = 0;
	}
}