#include "include/uerm.as"
#include "utils.as"
#include "spawnpoints.as"
#include "roles.as"
#include "players.as"
#include "round.as"
#include "lobby.as"
#include "bans.as"
#include "adminpanel.as"

void OnInitialize() // Initialize when script loads. Don't use WORLD functions there.
{
	RegisterAllCallbacks();

	AdminPanel::Register();
	PlayerCallbacks::Register();
	Lobby::Create();

	@GlobalBans = BanList("banlist.txt");
	
	CreateTimer(Round::Update, 1000, true);
	CreateTimer(Lobby::Update, 1000, true);
	
	server.disablenpcs = true; // Forcely set disablenpcs flag
	server.gamemode = "Breach";
	server.respawntime = 0;
	
	print("Loaded Breach gamemode.");
}

void OnWorldUpdate()
{
	for(int i = 0; i < connPlayers.size(); i++) {
		if(connPlayers[i].IsBot()) PlayerTimers::BotLogic(connPlayers[i]);
	}
}

void OnWorldLoaded()
{
	Lobby::Load();
}