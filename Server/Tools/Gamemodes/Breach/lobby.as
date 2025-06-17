namespace Lobby
{ 
	int LobbyTimer;
	
	void Create()
	{
		RoundTime = graphics.CreateText(NULL, 10, "00:00", 0.945, 0.017);
		LobbyGUI[0] = graphics.CreateText(NULL, 8, "&col[ffffff]WAITING FOR PLAYERS", 0.5, 0.15, true);
		LobbyGUI[1] = graphics.CreateText(NULL, 8, "NEED &col[ff0000]0 &col[ffffff]MORE PLAYERS TO START", 0.5, 0.2, true);
		LobbyGUI[0].SetShadow(true);
		LobbyGUI[1].SetShadow(true);
	}
	
	int GetTimer()
	{
		return LobbyTimer;
	}
	
	void SetTimer(int time)
	{
		LobbyTimer = time;
		if(LobbyTimer < 0) LobbyTimer = 0;
	}
	
	void Load()
	{
		Round::End(false);
		
		Roles::Initialize();
		
		Round::Create();
		Round::LoadSettings();
		Round::SpawnItems();
		Round::SetTimer(0);
		Round::SetWaveTimer(0);
		Round::SetWarheadsTimer(0);
		
		server.Console("unlockcheckpoints");

		LobbyElevator1 = NULL;
		LobbyElevator2 = NULL;
		
		Room r = world.GetRoomByIdentifier(r_gate_a);
		
		if(r != NULL) LobbyElevator1 = r.GetDoor(1);
		else
		{
			r = world.GetRoomByIdentifier(r_gate_a_b);
			if(r != NULL) {
				LobbyElevator1 = r.GetDoor(0);
				LobbyElevator2 = r.GetDoor(1);
			}
		}
		
		LobbyGUI[0].Show();
		LobbyGUI[1].Show();
		
		SetTimer(LOBBY_START_TIMER);
		Update();
	}
	
	void Update()
	{
		if(!Round::IsStarted()) {
			int c = MINIMUM_PLAYERS - GetPlayersCount();
			if(c > 0) {
				LobbyGUI[1].SetText("NEED &col[ff0000]" + c + " &col[ffffff]MORE PLAYERS TO START");
			}
			else {
				SetTimer(GetTimer() - 1);
				LobbyGUI[1].SetText("&colr[10 200 100]" + ConvertIntToTime(GetTimer(), false) + " &col[ffffff]left before the start");
				if(GetTimer() <= 0) 
				{
					// Starting round
					Round::Start();
				}
			}
		}
	}
	
	void TeleportPlayer(Player player)
	{
		Room r = world.GetRoomByIdentifier(r_gate_a);
		
		if(r != NULL) {
			Entity rooment = r.GetEntity();
			player.SetPosition(rooment.PositionX(), rooment.PositionY() + 0.4, rooment.PositionZ(), r);
			player.SetPositionBounds(r, rooment.PositionX(), rooment.PositionY() + 0.4, rooment.PositionZ(), 34.0);
		}
		else {
			r = world.GetRoomByIdentifier(r_gate_a_b);
			if(r != NULL) {
				float x, y, z;
				TFormRoom(r, 1386, 1305, 6632, x, y, z);
				player.SetPosition(x, y + 0.3, z, r);
				player.SetRotation(0, 90.0);
				player.SetPositionBounds(r, TFormedX(), TFormedY() + 0.3, TFormedZ(), 70.0);
			}
		}
	}
}