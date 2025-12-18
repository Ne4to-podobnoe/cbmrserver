class info_Player
{
	info_Player()
	{
		
	}
	~info_Player()
	{
		
	}
	
	Player player;
	Role@ pClass;
	GUIElement[] pYouAre(2);
	GUIElement RoleInfo;
	GUIElement hitElement;
	GUIElement cuffElement;
	int roleTimer;
	int logicTimer;
	int animTimer;
	float[] botState(8);
	float blinkInterval;
	float idleSoundTimer;
	Player linkedPlayer;
	Player cuffer;
	Player targetBotPlayer;
	// 096 Logic
	float soundTimer;
	float triggerTime;
	bool triggered;
	array<GUIElement> triggeredPlayers(MAX_PLAYERS + 1);
	bool hasGUI;
	// Intercom
	int intercomTimer;
	float intercomTimeout;
	//
	int recontainState;
}

class PlayerModel
{
	PlayerModel()
	{
		modelid = -1;
	}
	
	PlayerModel(int model, array<int> texture = {})
	{
		modelid = model;
		textures = texture;
	}
	
	int modelid;
	array<int> textures;
}

info_Player@[] PlayersInfo(MAX_PLAYERS + 1);
array<Player> connPlayers;
BanList@ GlobalBans;

info_Player@ CreatePlayerInfo(Player p)
{
	@PlayersInfo[p.GetIndex()] = info_Player();
	PlayersInfo[p.GetIndex()].player = p;
	return GetPlayerInfo(p);
}

void RemovePlayerInfo(Player p)
{
	@PlayersInfo[p.GetIndex()] = null;
}

info_Player@ GetPlayerInfo(Player p)
{
	return PlayersInfo[p.GetIndex()];
}

void SetPlayerRole(Player p, Role@ targetRole, int texture = -1)
{
	info_Player@ playerInfo = GetPlayerInfo(p);

	if(@targetRole == null) { // Lobby Player
		p.Respawn();
		p.Console("heal");
		Lobby::TeleportPlayer(p);
		
		for(int i = 0; i < MAX_PLAYER_INVENTORY; i++) {
			Items it = p.GetInventory(i);
			if(it != NULL) it.Remove();
		}
		
		NullPlayerStats(p);
		
		@playerInfo.pClass = null;
		
		p.SetModel(CLASS_D_MODEL);
		return;
	}

	if(@playerInfo.pClass != @targetRole) 
	{
		if(targetRole.roleid == 0) p.Kill(false, false);
		else if(targetRole.model.modelid != -1) {
			for(int i = 0; i < MAX_PLAYER_INVENTORY; i++) {
				Items it = p.GetInventory(i);
				if(it != NULL) it.Remove();
			}
			
			p.Respawn();
			p.Console("heal");
			
			for(int i = 0; i < targetRole.items.size(); i++) {
				if(targetRole.items[i].findFirst(";") >= 0) {
					Items backpack = world.CreateItem("Backpack");
					if(backpack != NULL) {
						array<string>@ values = targetRole.items[i].split(";");
						for(int x = 0; x < values.size(); x++) {
							Items it = world.CreateItem(values[x]);
							if(it != NULL) {
								if(values[x] == "Radio Transceiver") {
									it.SetState(1000.0);
									it.SetState2(targetRole.radioChannel);
								}
								
								backpack.PushItem(it);
							}
						}
					}
					
					backpack.SetPicker(p);
				}
				else {
					Items it = world.CreateItem(targetRole.items[i]);
					if(it != NULL) {
						if(targetRole.items[i] == "Radio Transceiver") { 
							it.SetState(1000.0);
							it.SetState2(targetRole.radioChannel);
						}
						it.SetPicker(p);
					}
				}
			}
			
			audio.PlaySoundForPlayer(p, "SFX/Ending/GateA/Bell0.ogg");
		}

		if(targetRole.spawnPoints.size() > 0) 
		{
			Spawnpoint currentSpawnpoint = targetRole.spawnPoints[rand(0, targetRole.spawnPoints.size() - 1)];
			p.SetPosition(currentSpawnpoint.x, currentSpawnpoint.y, currentSpawnpoint.z, currentSpawnpoint.room);
			p.SetRotation(currentSpawnpoint.pitch, currentSpawnpoint.yaw);
		}
	
		if(targetRole.model.modelid != -1) p.SetModel(targetRole.model.modelid, texture == -1 ? (targetRole.model.textures.empty() ? -1 : targetRole.model.textures[rand(0, targetRole.model.textures.size() - 1)]) : texture);
			
		NullPlayerStats(p);
		
		@playerInfo.pClass = targetRole;
		
		CreateRoleMessage(p);
		
		playerInfo.RoleInfo.SetText("&colr[" + targetRole.color.R() + " " + targetRole.color.G() + " " + targetRole.color.B() + "]" + targetRole.name);
		p.SetGodmode(targetRole.godmode);
		
		p.SetPositionBounds(NULL);
	}
}

void NullPlayerStats(Player p)
{
	info_Player@ playerInfo = GetPlayerInfo(p);
	Role@ prevRole = playerInfo.pClass;
	// Null
	p.SetStaminaMultiplier(1.0);
	p.SetAttach(ATTACH_WRIST, 0);
	p.SetInvisible(false);
	p.IgnoreProximity(false);
	p.Desync(false);
	p.SetInjuries(0.0);
	p.SetBloodloss(0.0);
	playerInfo.cuffer = NULL;
	
	if(@prevRole != null) {
		for(int i = 0; i < connPlayers.size(); i++) {
			p.SetLocalInvisible(connPlayers[i], false);
			connPlayers[i].SetLocalInvisible(p, false);
		}
	}
	
	if(playerInfo.hasGUI) {
		for(int i = 0; i <= MAX_PLAYERS; i++) {
			if(playerInfo.triggeredPlayers[i] != NULL) {
				playerInfo.triggeredPlayers[i].Remove();
				playerInfo.triggeredPlayers[i] = NULL;
			}
		}
		p.SetSpeedMultiplier(1.0);
		playerInfo.hasGUI = false;
	}
}

void UpdatePlayerRole(Player p)
{
	info_Player@ playerInfo = GetPlayerInfo(p);
	
	if(!p.IsDead() && p.GetInjuries() > 8.5) KillPlayer(p, NULL, "for unknown reason");
	
	if(playerInfo.cuffer != NULL && playerInfo.cuffer.IsDead()) playerInfo.cuffer = NULL;
	
	if(@playerInfo.pClass == null) return;
	
	bool Timeout = (playerInfo.pClass.category == CATEGORY_ANOMALY && (ROUND_TIME - Round::GetTimer() < SCP_TIMEOUT));
	p.Desync(Timeout);
	
	if(playerInfo.pClass.idleSounds.size() > 0) {
		playerInfo.idleSoundTimer += 0.1;
		if(playerInfo.idleSoundTimer >= playerInfo.pClass.idleSoundTime) {
			string sound = playerInfo.pClass.idleSounds[rand(0, playerInfo.pClass.idleSounds.size() - 1)];
			audio.Play3DSound(sound, p, 15.0, 0.8);
			audio.PlaySoundForPlayer(p, sound);
			playerInfo.idleSoundTimer = 0.0;
		}
	}

	switch(playerInfo.pClass.roleid) 
	{
		case 0:
		{
			break;
		}
		case ROLE_SCP_939:
		{
			for(int i = 0; i < connPlayers.size(); i++) {
				Player dest = connPlayers[i];
				p.SetLocalInvisible(dest, (!IsPlayerFriend(dest, p) && (dest.GetVolume() - (dest.GetEntity().Distance(p.GetEntity()) * 0.1)) < 1.5 + round(dest.IsCrouch()) * 2) ? true : false);
			}
			break;
		}
		case ROLE_SCP_966:
		{
			for(int i = 0; i < connPlayers.size(); i++) {
				Player dest = connPlayers[i];
				dest.SetLocalInvisible(p, (!IsPlayerFriend(dest, p) && 
				!(dest.GetAttach(0) == NVG_ATTACHMODEL 
				|| dest.GetAttach(0) == NVG_FINE_ATTACHMODEL
				|| dest.GetAttach(0) == NVG_VERYFINE_ATTACHMODEL)) ? true : false);
			}
			break;
		}
		case ROLE_SCP_173:
		{
			playerInfo.blinkInterval -= 0.1;
			if(playerInfo.blinkInterval <= 0.0) {
				SetProximityBlinking(p, 0.75);
				playerInfo.blinkInterval = 10;
			}
	
			bool visible = false;
			for(int i = 0; i < connPlayers.size(); i++) 
			{
				Player dest = connPlayers[i];
				if(!dest.IsDead() && 
				!IsPlayerFriend(p, dest) && 
				p.GetRoom().IsAdjacent(dest.GetRoom()) && 
				!dest.IsBlinking() && 
				p.GetHitbox().InView(dest.GetHead()) && 
				(dest.GetHead().Visible(p.GetEntity()) || dest.GetHead().Visible(p.GetHead()))) {
					visible = true;
					break;
				}
			}
			
			p.Desync(visible || Timeout);
			break;
		}
		case ROLE_SCP_096:
		{
			for(int i = 0; i < connPlayers.size(); i++) 
			{
				Player dest = connPlayers[i];
				info_Player@ destInfo = GetPlayerInfo(dest);
				if(playerInfo.triggeredPlayers[dest.GetIndex()] == NULL && 
				!dest.IsDead() && 
				!dest.IsBlinking() &&
				!IsPlayerFriend(p, dest) &&
				p.GetRoom().IsAdjacent(dest.GetRoom()) &&
				p.GetHead().InView(dest.GetHead()) && 
				dest.GetHead().InView(p.GetHead()) && 
				dest.GetHead().Visible(p.GetHead())) 
				{
					if(dest.GetAttach(ATTACH_FACE) == SCRAMBLE_ATTACHMODEL || dest.GetAttach(ATTACH_FACE) == SCRAMBLE_FINE_ATTACHMODEL) continue;
					
					if(!playerInfo.triggered) {
						p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_IDLE_ARMED_PISTOL);
						audio.Play3DSound("SFX\\Music\\096Angered.ogg", p, 20.0, 0.8);
						audio.PlaySoundForPlayer(p, "SFX\\Music\\096Angered.ogg");
						playerInfo.triggered = true;
					}
					
					playerInfo.triggeredPlayers[dest.GetIndex()] = graphics.CreateRect(p, 0, 0, 0.012, 0.022);
					playerInfo.triggeredPlayers[dest.GetIndex()].SetColor(255, 0, 0);
					playerInfo.triggeredPlayers[dest.GetIndex()].SetAttach(dest);
					playerInfo.hasGUI = true;
					audio.PlaySoundForPlayer(dest, "SFX\\SCP\\096\\Triggered.ogg");
				}
				else if(destInfo.triggeredPlayers[p.GetIndex()] != NULL) {
					destInfo.triggeredPlayers[p.GetIndex()].Remove();
					destInfo.triggeredPlayers[p.GetIndex()] = NULL;
				}
			}
			
			if(playerInfo.triggered) {
				p.IgnoreProximity(true);
				
				playerInfo.triggerTime += 0.1;
				
				p.SetSpeedMultiplier(playerInfo.triggerTime > 30.0 ? 2.0 : 0.25);
				
				if(playerInfo.triggerTime > 30.0) {
					p.SetStaminaMultiplier(1.0);
					playerInfo.triggered = false;
					playerInfo.soundTimer -= 0.1;
					
					if(playerInfo.triggerTime - 0.1 < 30.0) 
					{
						for(int i = 0; i < connPlayers.size(); i++) 
						{
							if(playerInfo.triggeredPlayers[connPlayers[i].GetIndex()] != NULL) {
								audio.PlaySoundForPlayer(connPlayers[i], "SFX\\Music\\096Chase.ogg");
							}
						}
					}
					
					if(playerInfo.soundTimer <= 0.0) 
					{
						audio.Play3DSound("SFX\\SCP\\096\\Scream.ogg", p, 20.0, 0.8);
						audio.PlaySoundForPlayer(p, "SFX\\SCP\\096\\Scream.ogg");
						playerInfo.soundTimer = 10.0;
					}
					
					for(int i = 0; i < MAX_DOORS; i++) {
						Door d = world.GetDoor(i);
						if(d != NULL && d.GetEntity().DistanceSquared(p.GetEntity()) <= 2.5 && d.GetLockState() == 0 && !d.IsOpened()) {
							d.SetOpen(true);
							break;
						}
					}
				}
				else playerInfo.soundTimer = 0.0;
				
				for(int i = 0; i <= MAX_PLAYERS; i++)
				{
					if((@PlayersInfo[i] == null || PlayersInfo[i].player.IsDead()) && playerInfo.triggeredPlayers[i] != NULL) {
						playerInfo.triggeredPlayers[i].Remove();
						playerInfo.triggeredPlayers[i] = NULL;
						continue;
					}
					
					if(playerInfo.triggeredPlayers[i] != NULL) playerInfo.triggered = true;
				}
				
				if(!playerInfo.triggered || playerInfo.triggerTime > 60.0) 
				{
					playerInfo.triggerTime = 0.0;
					playerInfo.triggered = false;

					for(int i = 0; i <= MAX_PLAYERS; i++) {
						if(playerInfo.triggeredPlayers[i] != NULL) {
							playerInfo.triggeredPlayers[i].Remove();
							playerInfo.triggeredPlayers[i] = NULL;
						}
					}
				}
			}
			else {
				p.SetStaminaMultiplier(50.0);
				p.SetSpeedMultiplier(1.0);
				p.IgnoreProximity(false);
			}
			break;
		}
		case ROLE_SCP_035:
		{
			p.SetInjuries(p.GetInjuries() + 0.0005);
			break;
		}
		default:
		{
			for(int i = 0; i < Roles::GetEscapeSections().size(); i++) {
				EscapeSection@ seq = Roles::GetEscapeSections()[i];
				if(seq.room != NULL && p.GetRoom() == seq.room) 
				{
					Entity pEnt = p.GetEntity();
					if(DistanceSquared(vector3(seq.x, seq.y, seq.z), vector3(pEnt.PositionX(), pEnt.PositionY(), pEnt.PositionZ())) < 9.0 && seq.allowedRoles.findByRef(playerInfo.pClass) >= 0)
					{
						if(seq.category == playerInfo.pClass.category) {
							SetPlayerRole(p, seq.toAssign);
							if(CategoryEscaped.size() > 0) CategoryEscaped[seq.category]++;
						}
						else if(p.GetAttach(ATTACH_WRIST) == WEAPON_CUFFED_ATTACHMODEL) { // If cuffed
							SetPlayerRole(p, seq.toAssign);
							if(CuffedCategoryEscaped.size() > 0) CuffedCategoryEscaped[seq.category]++;
						}
						break;
					}
				}
			}
		}
	}
}

void CreateRoleMessage(Player p)
{
	info_Player@ playerInfo = GetPlayerInfo(p);
	DestructRoleMessage(p);
			
	Role@ playerRole = playerInfo.pClass;
	
	int timerData = CreateTimerData();
	SetTimerHandle(timerData, p);
	playerInfo.roleTimer = CreateTimer(SetRoleTextOpacity, 5000, false, timerData);
	
	playerInfo.pYouAre[0] = graphics.CreateText(p, 8, "&col[ffffff]YOU ARE &colr[" + playerRole.color.R() + " " + playerRole.color.G() + " " + playerRole.color.B() +"]" + playerRole.name, 0.5, 0.15, true);
	playerInfo.pYouAre[1] = graphics.CreateText(p, 8, "&col[ffffff] " + playerRole.rTask, 0.5, 0.2, true);
	
	//chat.Send(p.GetName() + " is a &colr[" + playerRole.color.R() + " " + playerRole.color.G() + " " + playerRole.color.B() +"]" + playerRole.name);
}

void SetRoleTextOpacity(Player p)
{
	info_Player@ playerInfo = GetPlayerInfo(p);
	
	int timerData = CreateTimerData();
	SetTimerHandle(timerData, p);
	playerInfo.roleTimer = CreateTimer(DestructRoleMessage, 5000, false, timerData);
	
	playerInfo.pYouAre[0].SetOpacity(0.0, 100.0);
	playerInfo.pYouAre[1].SetOpacity(0.0, 100.0);
}

void DestructRoleMessage(Player p)
{
	info_Player@ playerInfo = GetPlayerInfo(p);
	if(playerInfo.pYouAre[0] != NULL) {
		playerInfo.pYouAre[0].Remove();
		playerInfo.pYouAre[0] = NULL;
	}
	
	if(playerInfo.pYouAre[1] != NULL) {
		playerInfo.pYouAre[1].Remove();
		playerInfo.pYouAre[1] = NULL;
	}
	
	if(playerInfo.roleTimer != 0) {
		RemoveTimer(playerInfo.roleTimer);
		playerInfo.roleTimer = 0;
	}
}

string GetPlayerStatus(Player p)
{
	if(p.IsDead()) return "Dead";
	info_Player@ info = GetPlayerInfo(p);
	float multiplier = @info.pClass != null ? info.pClass.damagemultiplier : 1.0f;
	float maxhealth = 8.0 / multiplier;
	float delta = 1.0f - (min(p.GetInjuries(), 8.0) / 8.0);
	return "&colr[200 30 30]" + int(maxhealth * 12.5 * delta) + " HP";
	/*float bloodloss = p.GetBloodloss();
	
	if(bloodloss > 20.0 && injuries < 4.0) return "&colr[255 100 0]Bad";
	if(bloodloss > 60.0) return "&colr[255 0 0]Half-dead";
	
	if(injuries <= 0.0) return "&colr[0 255 0]Fine";
	if(injuries > 0.0 && injuries < 1.0) return "&colr[130 255 0]Quite well";
	if(injuries >= 1.0 && injuries < 2.0) return "&colr[230 255 0]Well";
	if(injuries >= 2.0 && injuries < 4.0) return "&colr[255 100 0]Bad";
	if(injuries >= 4.0 && injuries < 6.0) return "&colr[255 50 0]Very bad";
	if(injuries >= 6.0 && injuries <= 8.0) return "&colr[255 0 0]Half-dead";
	return "&colr[0 255 0]Fine";*/
}

void SetPlayerInterval(Player p, float time)
{
	info_Player@ playerInfo = GetPlayerInfo(p);
	PlayerTimers::PlayerHitCallback(playerInfo.hitElement);
	playerInfo.hitElement = graphics.CreateProgressBar(p, time, 0.5, 0.9, 0.15, 0.015, true, "PlayerTimers::PlayerHitCallback");
	playerInfo.hitElement.SetColor(150, 0, 0);
}

void UpdatePlayerCapture(Player p)
{
	info_Player@ playerInfo = GetPlayerInfo(p);
	if(playerInfo.linkedPlayer != NULL && !playerInfo.linkedPlayer.IsDead() && !p.IsDead()) {
		float x, y, z, yaw, pitch;
		p.GetNetworkPosition(x, y, z);
		p.GetNetworkRotation(pitch, yaw);
		playerInfo.linkedPlayer.Desync(true);
		playerInfo.linkedPlayer.SetPosition(x, y, z, p.GetRoom());
		playerInfo.linkedPlayer.SetRotation(0, yaw);
		playerInfo.linkedPlayer.SetAnimation(PLAYER_MODEL_ANIMATION_INJURED_IDLE);
		UpdatePlayerCapture(playerInfo.linkedPlayer);
	}
}

void SetProximityBlinking(Player p, float time)
{
	for(int i = 0; i < connPlayers.size(); i++) {
		if(!IsPlayerFriend(p, connPlayers[i]) && connPlayers[i].GetEntity().DistanceSquared(p.GetEntity()) <= 300.0) 
		{
			connPlayers[i].SetBlinkEffect(1000.0, time);
		}
	}
}

bool IsPlayerFriend(Player src, Player dest)
{
	info_Player@ playerInfosrc = GetPlayerInfo(src);
	info_Player@ playerInfodest = GetPlayerInfo(dest);
	if(@playerInfosrc.pClass == null) return false;
	return playerInfosrc.pClass.IsAFriend(playerInfodest.pClass);
}

bool IsPlayerFriend(Player src, Role@ role)
{
	info_Player@ playerInfosrc = GetPlayerInfo(src);
	if(@playerInfosrc.pClass == null) return false;
	return playerInfosrc.pClass.IsAFriend(role);
}

void EndPlayerIntercom(Player p)
{
	info_Player@ playerInfo = GetPlayerInfo(p);
	if(playerInfo.intercomTimer != 0) {
		audio.PlaySound("SFX\\Character\\MTF\\EndAnnounc.ogg");
		p.SetGlobalTransmission(false);
		
		RemoveTimer(playerInfo.intercomTimer);
		playerInfo.intercomTimer = 0;
		playerInfo.intercomTimeout = 60.0;
	}
}

void KillPlayer(Player dest, Player killer, string reason = "")
{
	if(killer != NULL) chat.Send(killer.GetName() + " killed " + dest.GetName() + " " + reason);
	else if(reason != "") chat.Send(dest.GetName() + " died " + reason);
	dest.Kill();
}

void PlayPlayerAnimation(Player p, int anim, int time)
{
	StopPlayerAnimation(p);
	info_Player@ playerInfo = GetPlayerInfo(p);
	int timerData = CreateTimerData();
	SetTimerHandle(timerData, p);
	playerInfo.animTimer = CreateTimer(StopPlayerAnimation, time, false, timerData);
	p.SetAnimation(anim);
}

void StopPlayerAnimation(Player p)
{
	info_Player@ playerInfo = GetPlayerInfo(p);
	if(playerInfo.animTimer != 0) {
		RemoveTimer(playerInfo.animTimer);
		playerInfo.animTimer = 0;
	}
	
	p.SetAnimation(0);
}

namespace PlayerTimers
{
	void Logic(Player p)
	{
		info_Player@ playerInfo = GetPlayerInfo(p);
		if(p.IsDead()) {
			Player spectate = p.GetSpectatePlayer();
			if(spectate != NULL) {
				info_Player@ playerInfo_s = GetPlayerInfo(spectate);
				playerInfo.RoleInfo.SetText(spectate.GetName() + ((@playerInfo_s.pClass != null) ? playerInfo_s.pClass.GetFormatColor() + " (" + playerInfo_s.pClass.name : " (None") + ") &r[]Status: " + GetPlayerStatus(spectate));
				return;
			}
		}
		
		UpdatePlayerRole(p);
		if(@playerInfo.pClass != null) {
			playerInfo.RoleInfo.SetText(playerInfo.pClass.GetFormatColor() + playerInfo.pClass.name + ".&r[] Status: " + GetPlayerStatus(p));
		}
		else playerInfo.RoleInfo.SetText("");
		
		playerInfo.intercomTimeout -= 0.1;
	}

	void BotLogic(Player p)
	{
		info_Player@ playerInfo = GetPlayerInfo(p);
		if(!p.IsDead())
		{
			p.RedirectMove(true);
			
			playerInfo.botState[0] += 0.016;
			if(playerInfo.botState[0] >= 0.4)
			{
				Entity picked = p.GetEntity().Pick(0.3);
				if(picked == NULL)
				{
					playerInfo.botState[1] = 1.0;
					
					picked = p.GetEntity().Pick(3.0);
					if(picked == NULL) {
						playerInfo.botState[1] = 2.0;
					}
				}
				else {
					p.SetRotation(0, frand(-180, 180.0));
					playerInfo.botState[1] = 0.0;
				}
				
				playerInfo.botState[0] = 0.0;
				playerInfo.botState[5] = frand(4.0, 16.0);
			}
			
			for(int i = 0; i < 4; i++) {
				Room r = p.GetRoom().GetAdjacentRoom(i);
				if(r != NULL && r.IsInside(p.GetEntity()))
				{
					p.SetRoom(r);
					break;
				}
			}
			
			for(int i = 0; i < 4; i++) {
				Door d = p.GetRoom().GetAdjacentDoor(i);
				if(d != NULL && d.GetEntity().DistanceSquared(p.GetEntity()) <= 4.0 && !d.IsOpened() && d.GetLockState() == 0)
				{
					d.Use();
					break;
				}
			}
			
			switch(int(playerInfo.botState[1]))
			{
				case 0:
				{
					p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_IDLE);
					break;
				}
				case 1:
				{
					p.GetEntity().Move(0, 0, 0.018);
					p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_WALK);
					
					playerInfo.botState[4] += 0.016;
					if(playerInfo.botState[4] >= playerInfo.botState[5]) {
						p.SetRotation(0, frand(-180, 180.0));
						playerInfo.botState[1] = 0.0;
						playerInfo.botState[4] = 0.0;
					}
					break;
				}
				case 2:
				{
					p.GetEntity().Move(0, 0, 0.045);
					p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_RUN);
					playerInfo.botState[4] += 0.016;
					if(playerInfo.botState[4] >= playerInfo.botState[5] / 2.0) {
						p.SetRotation(0, frand(-180, 180.0));
						playerInfo.botState[1] = 0.0;
						playerInfo.botState[4] = 0.0;
					}
					break;
				}
				case 3:
				{
					if(playerInfo.targetBotPlayer != NULL) {
						p.GetHead().Point(playerInfo.targetBotPlayer.GetHead());
						p.SetRotation(p.GetHead().Pitch(true), p.GetHead().Yaw(true));
					}
					
					if(playerInfo.botState[0] > -4.0) {
						if(p.GetAttachItem(ATTACH_WEAPON) != NULL) {
							p.GetAttachItem(ATTACH_WEAPON).SetState(30.0);
							if(rand(0, 20) == 0) {
								p.SetShootsCount(p.GetShootsCount() + rand(0, 5));
							}
						}
					}
					
					p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_IDLE);
					
					if(playerInfo.botState[0] > -3.0) {
						p.GetEntity().Move(0, 0, -0.018);
						p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_WALK);
					}

					playerInfo.botState[2] = 0;
				}
			}
			
			if(playerInfo.targetBotPlayer != NULL && playerInfo.targetBotPlayer.IsDead()) playerInfo.targetBotPlayer = NULL;
			
			playerInfo.botState[2] += 0.016;
			if(playerInfo.botState[2] >= playerInfo.botState[6] / 2.0 && playerInfo.botState[0] >= 0.0) {
				array<Player> fplayers = connPlayers;
				
				while(!fplayers.empty())
				{
					int index = rand(0, fplayers.size()-1);
					Player dest = fplayers[index];
					fplayers.removeAt(index);
					
					if(dest != p && !dest.IsDead() && !IsPlayerFriend(dest, p) && p.GetEntity().DistanceSquared(dest.GetEntity()) <= 344.0 && dest.GetRoom().IsAdjacent(p.GetRoom()) && p.GetHead().Visible(dest.GetHead())) {
						playerInfo.botState[0] = -5.0;
						p.GetHead().Point(dest.GetHead());
						p.SetRotation(p.GetHead().Pitch(true), p.GetHead().Yaw(true));
						playerInfo.botState[1] = 3.0;
						playerInfo.targetBotPlayer = dest;
						break;
					}
				}
				playerInfo.botState[2] = 0.0;
			}
			
			playerInfo.botState[3] += 0.016;
			if(playerInfo.botState[3] >= playerInfo.botState[6] && p.GetAttachItem(ATTACH_WEAPON) == NULL && playerInfo.botState[0] >= 0.0) {
				for(int i = 0; i < MAX_PLAYER_INVENTORY; i++) {
					if(p.GetInventory(i) != NULL && p.GetInventory(i).IsWeapon())
					{
						p.SetWearData(5, p.GetInventory(i));
						break;
					}
				}

				for(int i = 1; i <= MAX_ITEMS; i++) {
					Items it = world.GetItem(i);
					if(it != NULL && it.GetEntity().DistanceSquared(p.GetEntity()) <= 4.0 && it.GetPicker() == NULL) {
						p.GetHead().Point(it.GetEntity());
						p.SetRotation(p.GetHead().Pitch(true), p.GetHead().Yaw(true));
						it.SetPicker(p);
						p.SetWearData(5, it);
						playerInfo.botState[1] = 0.0;
						playerInfo.botState[0] = -2.0;
						break;
					}
				}
				playerInfo.botState[3] = 0.0;
				playerInfo.botState[6] = frand(8.0, 15.0);
			}
			
			if(!p.GetEntity().Collided(1)) p.GetEntity().Translate(0, -0.025, 0);
		}
	}
	
	void RecontainmentProcedure(Player p, int state, float offset)
	{
		switch(state)
		{
			case 0:
			{
				audio.Play3DSound("SFX/Alarm/Alarm3.ogg", RecontainDoor.GetEntity(), 15.0, 0.8);
			
				int timerData = CreateTimerData();
				SetTimerHandle(timerData, p);
				SetTimerInt(timerData, 1);
				SetTimerFloat(timerData, 0.0);
				CreateTimer(RecontainmentProcedure, 2000, false, timerData);
				break;
			}
			case 1:
			{
				audio.PlaySound("SFX\\Room\\106Chamber\\FemurBreaker.ogg");
				
				if(p != NULL && GetPlayerInfo(p).recontainState != 0) {
					float x, y, z;
					TFormRoom(RecontainDoor.GetRoom(), 1088.0, -6222.0, 1824.0, x, y, z);
					
					
					p.SetPosition(x, y, z);
					p.SetRotation(0, RecontainDoor.GetRoom().GetEntity().Yaw() + 180.0);
					p.Kill();
					GetPlayerInfo(p).recontainState = 0;
				}
				
				int timerData = CreateTimerData();
				SetTimerHandle(timerData, p);
				SetTimerInt(timerData, 2);
				SetTimerFloat(timerData, 0.0);
				CreateTimer(RecontainmentProcedure, 5000, false, timerData);
				break;
			}
			case 2:
			{
				for(int i = 0; i < connPlayers.size(); i++) {
					Player dest = connPlayers[i];
					info_Player@ destInfo = GetPlayerInfo(dest);
					if(!dest.IsDead() && @destInfo.pClass != null && destInfo.pClass.roleid == ROLE_SCP_106) {
						float x, y, z;
						TFormRoom(RecontainDoor.GetRoom(), 823.0, -6400.0, 1663.0, x, y, z);
						dest.SetPosition(x, y + offset, z);
						dest.SetRotation(0, RecontainDoor.GetRoom().GetEntity().Yaw() - 45.0);
						dest.Desync(true);
						
						if(offset > 0.5) {
							dest.Kill();
						}
					}
				}
		
				if(offset > 0.5) return;
				int timerData = CreateTimerData();
				SetTimerHandle(timerData, 0);
				SetTimerInt(timerData, 2);
				SetTimerFloat(timerData, offset + 0.001);
				CreateTimer(RecontainmentProcedure, 25, false, timerData);
				break;
			}
		}
	}
	
	void PlayerUncuffPlayer(GUIElement gui)
	{
		Player p = gui.GetPlayer();
		Player hit = GetPlayer(parseInt(gui.GetData()));
		bool isAttempt = gui.GetData().findFirst(".") >= 0;
		
		GetPlayerInfo(p).cuffElement = NULL;
		gui.Remove();
		
		if(hit == NULL || p.GetEntity().Distance(hit.GetEntity()) > 1.5 || hit.IsDead())
		{
			p.SendMessage("You are too far away from the player.");
			return;
		}
		
		if(hit.GetAttach(ATTACH_WRIST) != WEAPON_CUFFED_ATTACHMODEL) {
			p.SendMessage("The player already uncuffed.");
			return;
		}

		if(isAttempt && rand(1, 100) > 25) 
		{
			p.SendMessage("The attempt failed, try again.");
			return;
		}
		
		p.SendMessage(isAttempt ? "You've successfully uncuffed the player." : "You've uncuffed the player.");
		
		if(!isAttempt) 
		{
			Items it = world.CreateItem("Handcuffs");
			if(it != NULL) it.SetPicker(p);
		}
		else audio.Play3DSound("SFX\\Weapons\\Handcuffs\\deploy.ogg", hit, 8.0, 0.8);
		
		hit.SendMessage("You've been uncuffed");
		
		hit.SetAttach(ATTACH_WRIST, 0);
		GetPlayerInfo(hit).cuffer = NULL;
	}

	void PlayerCuffPlayer(GUIElement gui)
	{
		Player p = gui.GetPlayer();
		Player hit = GetPlayer(parseInt(gui.GetData()));
		
		GetPlayerInfo(p).cuffElement = NULL;
		gui.Remove();
		
		if(p.GetAttach(ATTACH_WEAPON) != WEAPON_CUFFS_ATTACHMODEL) return;
		
		if(hit == NULL || p.GetEntity().Distance(hit.GetEntity()) > 1.5 || hit.IsDead())
		{
			p.SendMessage("You are too far away from the player.");
			return;
		}
		
		if(hit.GetAttach(ATTACH_WRIST) == WEAPON_CUFFED_ATTACHMODEL) {
			p.SendMessage("The player already cuffed.");
			return;
		}

		hit.SetAttach(ATTACH_WRIST, WEAPON_CUFFED_ATTACHMODEL);
		GetPlayerInfo(hit).cuffer = p;
		hit.SendMessage("You've been cuffed by " + p.GetName() + ".");
		
		for(int i = 0; i < MAX_PLAYER_INVENTORY; i++) {
			Items it = hit.GetInventory(i);
			if(it != NULL) it.SetPicker(NULL);
		}

		p.GetAttachItem(ATTACH_WEAPON).Remove();
		p.SendMessage("You've cuffed the player.");
	}

	void CorpseAction(Corpse c, float timer, int remove)
	{
		if(remove != 0) {
			c.Remove();
			return;
		}
		
		c.SetTimeout(timer);
	}
	void PlayerHitCallback(GUIElement gui)
	{
		if(gui == NULL) return;
		
		GetPlayerInfo(gui.GetPlayer()).hitElement = NULL;
		gui.Remove();
	}
}

namespace PlayerCallbacks
{
	void Register()
	{
		RegisterCallback(PlayerConnect_c, OnConnect);
		RegisterCallback(PlayerDisconnect_c, OnDisconnect);
		RegisterCallback(PlayerChat_c, OnChat);
		RegisterCallback(PlayerHitPlayer_c, OnHitPlayer);
		RegisterCallback(PlayerDeath_c, OnDeath);
		RegisterCallback(PlayerShootPlayer_c, OnShootPlayer);
		RegisterCallback(PlayerExploreCorpse_c, OnExploreCorpse);
		RegisterCallback(PlayerTakeItem_c, OnTakeItem);
		RegisterCallback(PlayerDropItem_c, OnDropItem);
		RegisterCallback(PlayerUpdate_c, OnUpdate);
		RegisterCallback(PlayerClickObject_c, OnClickObject);
		RegisterCallback(PlayerUseDoorButton_c, OnUseDoorButton);
		RegisterCallback(PlayerUseItem_c, OnUseItem);
		RegisterCallback(PlayerUse914_c, OnUse914);
		RegisterCallback(PlayerAttachesUpdate_c, OnAttachesUpdate);
		RegisterCallback(PlayerClickGui_c, OnClickElement);
		RegisterCallback(ShellDamagePlayer_c, OnShellDamagePlayer);
	}
	
	void OnClickElement(Player player, GUIElement element)
	{
		if(element == NULL) return;
		element.Remove();
	}
	
	void OnConnect(Player player)
	{
		if(player == NULL) return; // Player was kicked on connection
		if(GlobalBans.Contains(parseUInt(player.GetSteamID()), IPToDecimal(player.GetIP())) >= 0)
		{
			player.Kick(CODE_BANNED);
			return;
		}
		
		info_Player@ playerInfo = CreatePlayerInfo(player);
		playerInfo.RoleInfo = graphics.CreateText(player, 0, "", 0.5, 0.98, true);

		if(Round::IsStarted()) 
		{
			player.SetPositionBounds(NULL);
			SetPlayerRole(player, Roles::GetRole(0));
			audio.PlaySoundForPlayer(player, "SFX/Ending/GateA/Bell0.ogg");
		}
		else SetPlayerRole(player, null);
		
		int timerData = CreateTimerData();
		SetTimerHandle(timerData, player);
		playerInfo.logicTimer = CreateTimer(PlayerTimers::Logic, 100, true, timerData);
		connPlayers.push_back(player);
		
		if(player.IsBot())
		{
			playerInfo.botState[6] = frand(8.0, 15.0);
		}
	}

	void OnDisconnect(Player player)
	{
		if(player == NULL) return; // Player was kicked on connection
		info_Player@ playerInfo = GetPlayerInfo(player);
		if(@playerInfo == null) return;
		DestructRoleMessage(player);
		StopPlayerAnimation(player);
		RemoveTimer(playerInfo.logicTimer);
		EndPlayerIntercom(player);
		RemovePlayerInfo(player);
		connPlayers.removeAt(connPlayers.find(player));
	}

	bool OnChat(Player player, string message)
	{
		if(message.substr(0, 1) == "/") 
		{
			info_Player@ playerInfo = GetPlayerInfo(player);
			array<string>@ values = message.split(" ");
			if(@values != null && !values.empty()) {
				string command = values[0].substr(1);
				
				if(command == "logadmin" || command == "bot")
				{
					return false;
				}
				
				if(command == "suicide")
				{
					if(!player.IsDead()) {
						const string[] phrases =
						{
							"died of a heart attack",
							"decided to gnaw their veins",
							"forgot how to breathe",
							"died of diarrhea",
							"slipped and hit his head",
							"took a nap"
						};
						
						chat.Send(player.GetName() + " " + phrases[rand(0, phrases.size() - 1)]);
						audio.PlaySoundForPlayer(player, "SFX\\SCP\\914\\PlayerDeath.ogg");
						audio.Play3DSound("SFX\\SCP\\914\\PlayerDeath.ogg", player, 15.0, 0.8);
						player.Kill(true);
					}
				}
				
				if(command == "panel")
				{
					AdminPanel::Show(player);
					return false;
				}

				if(command == "capture")
				{
					if(!player.IsDead() && player.IsAdmin())
					{
						if(values.size() >= 2) {
							int playerid = parseInt(values[1]);
							if(playerid <= MAX_PLAYERS) {
								if(playerInfo.linkedPlayer != NULL) {
									playerInfo.linkedPlayer.Desync(false);
									playerInfo.linkedPlayer.SetAnimation(0);
									playerInfo.linkedPlayer = NULL;
								}
								
								playerInfo.linkedPlayer = GetPlayer(playerid);
								if(playerInfo.linkedPlayer != NULL && GetPlayerInfo(playerInfo.linkedPlayer).linkedPlayer != player) {
									playerInfo.linkedPlayer.SendMessage("You have been captured by a player.");
									player.SendMessage("You have captured a player.");
								}
								else {
									player.SendMessage("Can't capture or find a player");
									playerInfo.linkedPlayer = NULL;
								}
							}
						}
						else if(playerInfo.linkedPlayer != NULL) {
							playerInfo.linkedPlayer.Desync(false);
							playerInfo.linkedPlayer.SetAnimation(0);
							playerInfo.linkedPlayer = NULL;
							player.SendMessage("You left the player.");
						}
					}
					return false;
				}
			}
			
			chat.SendPlayer(player, "Unknown command.");
			return false;
		}
		
		return true;
	}

	void OnHitPlayer(Player p, Player hit, int mouse, float distance)
	{
		info_Player@ playerInfo = GetPlayerInfo(p);
		if((mouse & 1 != 0))
		{
			if(@playerInfo.pClass != null && playerInfo.pClass.hitTime > 0.0 && distance < 1.5 && playerInfo.hitElement == NULL && ROUND_TIME - Round::GetTimer() >= SCP_TIMEOUT) 
			{
				if(!IsPlayerFriend(p, hit) || playerInfo.pClass.roleid == ROLE_SCP_999) 
				{
					switch(playerInfo.pClass.roleid) 
					{
						case ROLE_SCP_173:
						{
							if(!p.IsDesync()) {
								audio.Play3DSound("SFX/SCP/173/NeckSnap" + rand(0, 2) + ".ogg", hit.GetEntity(), 15.0, 0.8);
								KillPlayer(hit, p);
							}
							else return;
							break;
						}
						case ROLE_SCP_106:
						{
							audio.Play3DSound("SFX\\Character\\D9341\\Damage1.ogg", hit.GetEntity(), 8.0, 0.8);
							hit.SetInjuries(hit.GetInjuries() + frand(playerInfo.pClass.damage, playerInfo.pClass.damage * 1.1));
							if(hit.GetInjuries() >= 8.0) KillPlayer(hit, p);
							else {
								Room r = world.GetRoomByIdentifier(r_dimension_106);
								hit.SetPosition(r.GetEntity().PositionX(), r.GetEntity().PositionY() + 0.5, r.GetEntity().PositionZ(), r);
								hit.SetPositionBounds(NULL);
							}
							
							PlayPlayerAnimation(p, PLAYER_MODEL_ANIMATION_IDLE_ARMED_RIFLE, 1000);
							break;
						}
						case ROLE_SCP_0492:
						{
							audio.Play3DSound("SFX/Character/D9341/Damage" + rand(11, 12) + ".ogg", hit.GetEntity(), 8.0, 0.8);
							hit.SetInjuries(hit.GetInjuries() + frand(playerInfo.pClass.damage, playerInfo.pClass.damage * 1.1));
							if(hit.GetInjuries() >= 8.0) KillPlayer(hit, p);
							
							PlayPlayerAnimation(p, PLAYER_MODEL_ANIMATION_ZOMBIE_HIT, 1000);
							break;
						}
						case ROLE_SCP_457:
							audio.Play3DSound("SFX\\SCP\\294\\Burn.ogg", hit.GetEntity(), 8.0, 0.8);
							if(hit.GetModel() != HAZMAT_MODEL) {
								hit.SetInjuries(hit.GetInjuries() + frand(playerInfo.pClass.damage, playerInfo.pClass.damage * 1.1));
								if(hit.GetInjuries() >= 8.0) KillPlayer(hit, p);
							}
							else {
								for(int i = 0; i < MAX_PLAYER_INVENTORY; i++)
								{
									Items it = hit.GetInventory(i);
									if(it != NULL && (it.GetTemplateIndex() == it_hazmatsuit || it.GetTemplateIndex() == it_finehazmatsuit || it.GetTemplateIndex() == it_veryfinehazmatsuit || it.GetTemplateIndex() == it_hazmatsuit148)) { 
										it.Remove();
										hit.SendMessage("SCP-457 burned off your hazmat suit");
										break;
									}
								}
							}
							break;
						case ROLE_SCP_0492_GUARD:
						case ROLE_SCP_966:
						case ROLE_SCP_939:
						case ROLE_SCP_860:
						{
							audio.Play3DSound("SFX/Character/D9341/Damage" + rand(11, 12) + ".ogg", hit.GetEntity(), 8.0, 0.8);
							hit.SetInjuries(hit.GetInjuries() + frand(playerInfo.pClass.damage, playerInfo.pClass.damage * 1.1));
							if(hit.GetInjuries() >= 8.0) KillPlayer(hit, p);
							
							PlayPlayerAnimation(p, PLAYER_MODEL_ANIMATION_IDLE_ARMED_RIFLE + 2 * rand(0, 1), 1000);
							break;
						}
						case ROLE_SCP_049:
						{
							if(hit.GetAttach(ATTACH_FINGER) == SCP714_ATTACHMODEL) {
								for(int i = 0; i < MAX_PLAYER_INVENTORY; i++)
								{
									Items it = hit.GetInventory(i);
									if(it != NULL && (it.GetTemplateIndex() == it_scp714 || it.GetTemplateIndex() == it_fine714)) { 
										it.SetPicker(NULL);
										hit.SendMessage("SCP-049 took off your ring");
										break;
									}
								}
							}
							else if(hit.GetModel() == HAZMAT_MODEL) {
								for(int i = 0; i < MAX_PLAYER_INVENTORY; i++)
								{
									Items it = hit.GetInventory(i);
									if(it != NULL && (it.GetTemplateIndex() == it_hazmatsuit || it.GetTemplateIndex() == it_finehazmatsuit || it.GetTemplateIndex() == it_veryfinehazmatsuit || it.GetTemplateIndex() == it_hazmatsuit148)) { 
										it.SetPicker(NULL);
										hit.SendMessage("SCP-049 took off your hazmat suit");
										break;
									}
								}
							}
							else
							{
								audio.Play3DSound("SFX\\SCP\\049\\Horror.ogg", hit.GetEntity(), 8.0, 0.8);
								KillPlayer(hit, p);
							}
							break;
						}
						case ROLE_SCP_096:
						{
							if(playerInfo.triggerTime > 30.0 && playerInfo.triggeredPlayers[hit.GetIndex()] != NULL) {
								audio.Play3DSound("SFX\\Character\\D9341\\Damage4.ogg", hit.GetEntity(), 8.0, 0.8);
								KillPlayer(hit, p);
								PlayPlayerAnimation(p, PLAYER_MODEL_ANIMATION_IDLE_ARMED_RIFLE + 2 * rand(0, 1), 1000);
								p.SetModelTexture(SCP_096_BLOODY_TEXTURE);
							}
							else return;
							break;
						}
						case ROLE_SCP_999:
						{
							if(@GetPlayerInfo(hit) != null && @GetPlayerInfo(hit).pClass != null) {
								hit.SetInjuries(max(hit.GetInjuries() - (GetPlayerInfo(hit).pClass.damagemultiplier * 10), 0.0));
								audio.Play3DSound("SFX\\SCP\\999\\Gurgling" + rand(0, 3) + ".ogg", p.GetEntity(), 8.0, 0.8);
							}
							break;
						}
					}
					
					SetPlayerInterval(p, playerInfo.pClass.hitTime);
				}
				return;
			}
			
			if(distance < 1.5 && playerInfo.cuffElement == NULL) 
			{
				if(p.GetAttach(ATTACH_WEAPON) == WEAPON_CUFFS_ATTACHMODEL && p.GetAttachItem(ATTACH_WEAPON) != NULL) {
					if(hit.GetAttach(ATTACH_WRIST) != WEAPON_CUFFED_ATTACHMODEL) {
						info_Player@ hitInfo = GetPlayerInfo(hit);
						if(@hitInfo.pClass == null || (hitInfo.pClass.category != CATEGORY_ANOMALY && hitInfo.pClass.category != CATEGORY_ANOMALYSTALEMATE && ((!IsPlayerFriend(p, hit) && hit.GetAttach(ATTACH_WEAPON) == 0) || p.IsAdmin())))
						{
							p.SendMessage("Cuffing the player...");
							audio.Play3DSound("SFX\\Weapons\\Handcuffs\\equip.ogg", hit.GetEntity(), 8.0, 0.8);

							playerInfo.cuffElement = graphics.CreateProgressBar(p, 3.0, 0.5, 0.9, 0.15, 0.015, true, "PlayerTimers::PlayerCuffPlayer");
							playerInfo.cuffElement.SetColor(150, 150, 150);
							playerInfo.cuffElement.SetData(formatInt(hit.GetIndex()));
						}
						else p.SendMessage("You can't cuff this player.");
					}
					else p.SendMessage("This player already cuffed.");
				}
				else if(hit.GetAttach(ATTACH_WRIST) == WEAPON_CUFFED_ATTACHMODEL) {
					bool IsCuffer = GetPlayerInfo(hit).cuffer == p;
					p.SendMessage(IsCuffer ? "Uncuffing the player..." : "An attempt to uncuff the player...");
					audio.Play3DSound("SFX\\Weapons\\Handcuffs\\equip.ogg", hit.GetEntity(), 8.0, 0.8);
					playerInfo.cuffElement = graphics.CreateProgressBar(p, IsCuffer ? 1.0 : 5.0, 0.5, 0.9, 0.15, 0.015, true, "PlayerTimers::PlayerUncuffPlayer");
					playerInfo.cuffElement.SetColor(150, 150, 150);
					playerInfo.cuffElement.SetData(formatInt(hit.GetIndex()) + (IsCuffer ? "" : "."));
				}
			}
		}
	}
	void OnDeath(Player p, Corpse c)
	{
		info_Player@ playerInfo = GetPlayerInfo(p);
		if(@playerInfo.pClass != null) 
		{
			if(c != NULL) {
				if(playerInfo.pClass.category == CATEGORY_ANOMALY || playerInfo.pClass.category == CATEGORY_ANOMALYSTALEMATE) c.SetExplore(true);
				else {
					c.SetData(formatInt(playerInfo.pClass.roleid));
					if(c.GetModel() == MTF_MODEL || c.GetModel() == CHAOS_MODEL) {
						for(int i = 0; i < MAX_CORPSE_INVENTORY; i++) {
							Items item = c.GetItem(i);
							if(item != NULL && (item.GetTemplateIndex() == it_vest || item.GetTemplateIndex() == it_helmet)) {
								c.ExploreItem(i);
								item.Remove();
							}
						}
					}
				}
			}
			
			if(playerInfo.pClass.deadAnnouncement != "") 
			{
				bool found = false;
				for(int i = 0; i < connPlayers.size(); i++) {
					if(@GetPlayerInfo(connPlayers[i]).pClass != null && GetPlayerInfo(connPlayers[i]).pClass.IsRelative(playerInfo.pClass) && connPlayers[i] != p) {
						found = true;
						break;
					}
				}
				
				if(!found) audio.PlaySound(playerInfo.pClass.deadAnnouncement);
			}
		}
		
		SetPlayerRole(p, Roles::GetRole(0));
	}
	bool OnShootPlayer(Player src, Player dest, float x, float y, float z, float damage, bool headshot)
	{
		dest.SendDamage(src, damage, headshot, x, y, z);
		if(IsPlayerFriend(src, dest) && !Round::GetSettings().friendlyfire) return false;
		info_Player@ destInfo = GetPlayerInfo(dest);
		damage *= (@destInfo.pClass != null) ? destInfo.pClass.damagemultiplier : 1.0;
		dest.SetInjuries(dest.GetInjuries() + damage);
		if(dest.GetInjuries() >= 8.0 - damage) {
			if(IsPlayerFriend(src, dest) && Round::GetSettings().friendlyfirePunish) {
				KillPlayer(src, NULL);
				chat.SendPlayer(src, "You are being punished for killing an teammate.");
				chat.Send(src.GetName() + " killed " + dest.GetName() + " but was punished");
			}
			else KillPlayer(dest, src, headshot ? "in head" : "");
		}

		return false;
	}
	bool OnShellDamagePlayer(Shell shell, Player dest, float damage)
	{
		if(shell.GetShooter() == NULL || (IsPlayerFriend(shell.GetShooter(), dest) && !Round::GetSettings().friendlyfire)) return false;
		info_Player@ destInfo = GetPlayerInfo(dest);
		damage *= (@destInfo.pClass != null) ? destInfo.pClass.damagemultiplier : 1.0;
		dest.SetInjuries(dest.GetInjuries() + damage);
		if(dest.GetInjuries() >= 8.0) KillPlayer(dest, shell.GetShooter(), "by explosion");
		return false;
	}
	bool OnExploreCorpse(Player p, Corpse c)
	{
		info_Player@ playerInfo = GetPlayerInfo(p);
		if(@playerInfo.pClass != null && playerInfo.pClass.roleid == ROLE_SCP_049) {
			Player dest = c.GetPlayer();
			if(dest != NULL && dest.IsDead()) {
				
				info_Player@ destInfo = GetPlayerInfo(dest);
				Role@ previousRole = Roles::Find(parseInt(c.GetData()));
				if(@previousRole != null && @destInfo.pClass != null && !IsPlayerFriend(p, previousRole)) {
					PlayPlayerAnimation(p, PLAYER_MODEL_ANIMATION_IDLE_ARMED_RIFLE, 2000);
					
					int targetTex = -1;
					switch(previousRole.roleid)
					{
						case ROLE_SCIENTIST:
							targetTex = SCIENTIST_ZOMBIE_TEXTURE;
							break;
						case ROLE_JANITOR:
							targetTex = JANITOR_ZOMBIE_TEXTURE;
							break;
					}
					
					SetPlayerRole(dest, Roles::Find(c.GetModel() == GUARD_MODEL ? ROLE_SCP_0492_GUARD : ROLE_SCP_0492), c.GetModel() != GUARD_MODEL ? targetTex : -1);
					
					if(c.GetModel() == HAZMAT_MODEL) dest.SetModel(HAZMAT_MODEL, HAZMAT_ZOMBIE_TEXTURE); // If died with hazmat

					Entity cent = c.GetEntity();
					dest.SetPosition(cent.PositionX(), cent.PositionY() + 0.32, cent.PositionZ(), p.GetRoom());
					
					int timerData = CreateTimerData();
					SetTimerHandle(timerData, c);
					SetTimerFloat(timerData, c.GetTimeout());
					SetTimerInt(timerData, 1);
					CreateTimer(PlayerTimers::CorpseAction, 0, false, timerData);
					
					SetPlayerInterval(p, 2.0);
				}
			}
		}
		else {
			int timerData = CreateTimerData();
			SetTimerHandle(timerData, c);
			SetTimerFloat(timerData, c.GetTimeout());
			SetTimerInt(timerData, 0);
			CreateTimer(PlayerTimers::CorpseAction, 0, false, timerData);
			c.SetExplore(false);
			if(c.GetItemsCount() == 0) p.SendMessage("Nothing found");
		}
		return true;
	}
	bool OnTakeItem(Player p, Items it)
	{
		return ((@GetPlayerInfo(p).pClass == null || (GetPlayerInfo(p).pClass.category != CATEGORY_ANOMALY && GetPlayerInfo(p).pClass.category != CATEGORY_ANOMALYSTALEMATE) || GetPlayerInfo(p).pClass.model.modelid == -1) && p.GetAttach(ATTACH_WRIST) != WEAPON_CUFFED_ATTACHMODEL);
	}

	bool OnDropItem(Player p, Items it)
	{
		return ((@GetPlayerInfo(p).pClass == null || (GetPlayerInfo(p).pClass.category != CATEGORY_ANOMALY && GetPlayerInfo(p).pClass.category != CATEGORY_ANOMALYSTALEMATE) || GetPlayerInfo(p).pClass.model.modelid == -1) && p.GetAttach(ATTACH_WRIST) != WEAPON_CUFFED_ATTACHMODEL);
	}
	
	void OnUpdate(Player p)
	{
		info_Player@ playerInfo = GetPlayerInfo(p);
		UpdatePlayerCapture(p);
		
		if(@playerInfo.pClass == null) return;
		
		switch(playerInfo.pClass.roleid) // Animation replacer
		{
			case ROLE_SCP_096:
			{
				if(playerInfo.triggered) {
					switch(p.GetAnimation()) {
						case PLAYER_MODEL_ANIMATION_IDLE:
						{
							p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_IDLE_ARMED_PISTOL);
							break;
						}
						case PLAYER_MODEL_ANIMATION_WALK:
						{
							p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_WALK_ARMED_PISTOL);
							break;
						}
						case PLAYER_MODEL_ANIMATION_RUN:
						{
							if(playerInfo.triggerTime > 30.0) p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_RUN_ARMED_PISTOL);
							else p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_WALK_ARMED_PISTOL);
							break;
						}
					}
				}
				break;
			}
		}
	}
	void OnClickObject(Player p, Object obj)
	{
		info_Player@ playerInfo = GetPlayerInfo(p);
		if(obj == IntercomButton)
		{
			if(@playerInfo.pClass == null || ((playerInfo.pClass.category == CATEGORY_ANOMALY || playerInfo.pClass.category == CATEGORY_ANOMALYSTALEMATE) && playerInfo.pClass.roleid != ROLE_SCP_049)) { p.SendMessage("You can't use intercom."); return; }
			if(playerInfo.intercomTimeout > 0.0) { p.SendMessage("Wait " + int(playerInfo.intercomTimeout) + " seconds for a repeat intercom."); return; }
			if(playerInfo.intercomTimer != 0) { p.SendMessage("You can speak"); return; }
			
			audio.PlaySound("SFX\\Character\\MTF\\StartAnnounc.ogg");
			p.SendMessage("You can speak for a 20 seconds");
			
			int timerData = CreateTimerData();
			SetTimerHandle(timerData, p);
			playerInfo.intercomTimer = CreateTimer(EndPlayerIntercom, 20000, false, timerData);
			p.SetGlobalTransmission(true);
		}
		else if(obj == WarheadsButton)
		{
			if(!Round::IsStarted()) return;
			if(@playerInfo.pClass == null || playerInfo.pClass.category == CATEGORY_ANOMALY || playerInfo.pClass.category == CATEGORY_ANOMALYSTALEMATE) { p.SendMessage("You can't use warheads."); return; }
			if(ROUND_TIME * 0.5 < Round::GetTimer()) { p.SendMessage("You need to wait half a round to activate the warheads."); return; }
			if(Round::IsWarheadsEnabled()) { 
				if(Round::GetWarheadsTimer() > 88) return; // Can't disable by accident
				Round::EnableWarheads(false);
				p.SendMessage("You disabled the warheads"); 
				return; 
			}
			if(Round::GetWarheadsTimer() > 0) { p.SendMessage("You need to wait " + Round::GetWarheadsTimer() + " seconds to repeat"); return; }
			if(Round::EnableWarheads(true, 90)) p.SendMessage("Alpha Warheads has been activated!");
			else p.SendMessage("msg::key.nothappend", 6.0, true);
		}
		else if(obj == Mask035)
		{
			if(playerInfo.pClass.category != CATEGORY_ANOMALY && playerInfo.pClass.category != CATEGORY_ANOMALYSTALEMATE) {
				SetPlayerRole(p, Roles::Find(ROLE_SCP_035));
				audio.PlaySoundForPlayer(p, "SFX\\SCP\\914\\PlayerDeath.ogg");
				audio.Play3DSound("SFX\\SCP\\914\\PlayerDeath.ogg", p, 15.0, 0.8);
				
				Mask035.Remove();
				Mask035 = NULL;
			}
		}
		else if(obj == RecontainButton)
		{
			if(recontainState != 0 || !Round::IsStarted()) {
				p.SendMessage("The recontainment procedure has already been completed.");
				return;
			}
			float x, y, z;
			TFormRoom(obj.GetRoom(), -1455.9, -8022.6, 2662.1, x, y, z);

			for(int i = 0; i < connPlayers.size(); i++) {
				Player dest = connPlayers[i];
				if(!dest.IsDead() && dest != p) {
					info_Player@ destInfo = GetPlayerInfo(dest);
					Entity pent = dest.GetEntity();
					if(destInfo.pClass.category != CATEGORY_ANOMALY && destInfo.pClass.category != CATEGORY_ANOMALYSTALEMATE
					&& DistanceSquared(vector3(x, y, z), vector3(pent.PositionX(),pent.PositionY(),pent.PositionZ())) <= 0.6) {
						int timerData = CreateTimerData();
						SetTimerHandle(timerData, dest);
						SetTimerInt(timerData, 0);
						SetTimerFloat(timerData, 0.0);
						CreateTimer(PlayerTimers::RecontainmentProcedure, 2000, false, timerData);
						destInfo.recontainState = 1;
						
						audio.Play3DSound("SFX/Door/DoorOpen2.ogg", Recontainer.GetEntity(), 15.0, 0.8);
						RecontainDoor.GetEntity().SetPosition(-1366.28, -8100.0, 2667.61);
						recontainState = 1;
						return;
					}
				}
			}
			
			p.SendMessage("There is no suitable object in the cell.");
		}
	}
	bool OnUseDoorButton(Player p, Door door, Items item)
	{
		if((door == LobbyElevator1 || door == LobbyElevator2) && !Round::IsStarted()) return false;
		info_Player@ playerInfo = GetPlayerInfo(p);
		if(@playerInfo.pClass != null && ((playerInfo.pClass.category == CATEGORY_ANOMALY && playerInfo.pClass.roleid != ROLE_SCP_035) || playerInfo.pClass.category == CATEGORY_ANOMALYSTALEMATE) && door.GetDoorAccess() == DOOR_KEYCARD && door.GetDoorType() != BIG_DOOR && door.GetLockState() == 0) {
			door.Use();
			p.SendMessage(" ");
			return false;
		}
		return true;
	}
	bool OnUseItem(Player p, Items item)
	{
		if(item.GetTemplateName().findFirst("Aid") >= 0)
		{
			p.SetInjuries(0.0);
			p.SetBloodloss(0.0);
			p.SendMessage("msg::aid.stopall", 6.0, true);
			return false;
		}
		return true;
	}
	void OnUse914(Player p, int setting)
	{
		for(int i = 0; i < MAX_PLAYER_INVENTORY; i++) {
			Items it = p.GetInventory(i);
			if(it != NULL && it.GetSlots() == 0) {
				Items refined = it.Fine(setting);
				if(it != NULL) it.SetPicker(p);
				if(refined != NULL) refined.SetPicker(p);
			}
		}
	}
	void OnAttachesUpdate(Player p)
	{
		info_Player@ playerInfo = GetPlayerInfo(p);
		if(@playerInfo.pClass != null) {
			switch(playerInfo.pClass.roleid)
			{
				case ROLE_SCP_035:
					p.SetAttach(ATTACH_FACE, SCP035_ATTACHMODEL);
					break;
				case ROLE_SCP_106:
					p.SetAttach(ATTACH_WRIST, WEAPON_VIEWMODEL106_ATTACHMODEL);
					break;
				case ROLE_SCP_173:
					p.SetAttach(ATTACH_WRIST, WEAPON_VIEWMODEL173_ATTACHMODEL);
					break;
				case ROLE_SCP_096:
					p.SetAttach(ATTACH_WRIST, WEAPON_VIEWMODEL096_ATTACHMODEL);
					break;
				case ROLE_SCP_966:
					p.SetAttach(ATTACH_WRIST, WEAPON_VIEWMODEL966_ATTACHMODEL);
					break;
				case ROLE_SCP_049:
					p.SetAttach(ATTACH_WRIST, WEAPON_VIEWMODEL049_ATTACHMODEL);
					break;
			}
		}
	}
}