#include "include/uerm.as"

Player myBot;
float[] botState(6);
Waypoint way;
Waypoint fleeWay;
Room fleeRoom;
Player target;
float headTiltTimer;
float idleTimer;
float fleeTimer;
int idleState;
bool wasWatched;

void OnInitialize()
{
	RegisterAllCallbacks();
	OnWorldLoaded();
	botState[0] = 5.0f;
}

void OnWorldLoaded()
{
	if(world && myBot == NULL) {
		myBot = world.CreateBot("...");
	}
}

void OnPlayerDisconnect(Player p) {
	if(p == myBot) myBot = NULL;
}

void OnTerminate()
{
	if(myBot != NULL) myBot.Kick();
}

void OnWorldUpdate()
{
	if(myBot == NULL || myBot.IsDead()) return;

	if(target == NULL || target.IsDead()) {
		for(auto it = Player::Iterator(); it != NULL; it++) {
			if(!it.Get().IsBot() && !it.Get().IsDead()) { target = it.Get(); break; }
		}
		if(target == NULL) return;
	}

	BotLogic(myBot);
}

void BotLogic(Player p)
{
	if(p.IsDead()) return;

	Entity pEnt = p.GetEntity();
	Entity tEnt = target.GetEntity();
	float dist = pEnt.Distance(tEnt);

	p.RedirectMove(true);
	p.GetHead().Point(tEnt);

	float dt = 0.016f;
	float yaw = p.GetHead().Yaw(true);
	float pitch = p.GetHead().Pitch(true);

	headTiltTimer += dt;
	idleTimer += dt;

	bool watched = false;
	if(!target.IsDead() && !target.IsBlinking()) {
		if(target.GetHead().InView(p.GetHead()) && target.GetHead().Visible(p.GetHead())) {
			watched = true;
		}
	}

	if(dist < 3.0f) {
		// Flee - run to adjacent room via waypoints
		if(fleeRoom == NULL) {
			fleeTimer = 0.0f;
			Room playerRoom = target.GetRoom();
			if(playerRoom != NULL) {
				bool[] tried(4);
				for(int n = 0; n < 4; n++) {
					int idx = rand(0, 3);
					if(tried[idx]) continue;
					tried[idx] = true;
					Room adj = playerRoom.GetAdjacentRoom(idx);
					if(adj != NULL && adj != playerRoom) { fleeRoom = adj; break; }
				}
			}
		}

		// Open doors
		if(fleeWay != NULL) {
			Door wpDoor = fleeWay.GetDoor();
			if(wpDoor != NULL && !wpDoor.IsOpened() && wpDoor.GetLockState() == 0 && wpDoor.GetEntity().DistanceSquared(pEnt) <= 4.0) {
				wpDoor.Use();
			}
		}
		for(int i = 0; i < 4; i++) {
			Door d = p.GetRoom().GetAdjacentDoor(i);
			if(d != NULL && !d.IsOpened() && d.GetLockState() == 0 && d.GetEntity().DistanceSquared(pEnt) <= 4.0) {
				d.Use();
			}
		}

		fleeTimer += dt;

		bool needNewWay = (fleeWay == NULL);
		if(fleeWay != NULL) {
			float wayDist = fleeWay.GetEntity().Distance(pEnt);
			if(wayDist < 0.5) needNewWay = true;
		}
		if(fleeRoom != NULL && needNewWay && fleeTimer > 0.6f) {
			Waypoint newWay = world.FindWaypoint(pEnt, fleeRoom.GetEntity());
			if(newWay != NULL && newWay.GetEntity().Distance(pEnt) > 0.5) {
				fleeWay = newWay;
			}
			else {
				fleeRoom = NULL;
				fleeWay = NULL;
			}
			fleeTimer = 0.0f;
		}

		if(fleeWay != NULL) {
			p.GetHead().Point(fleeWay.GetEntity());
			float wayYaw = p.GetHead().Yaw(true);
			p.GetHead().Point(tEnt);
			p.SetRotation(pitch, wayYaw);
			p.GetEntity().Move(0, 0, 0.05);
			p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_RUN);
		}
		else {
			float fleeYaw = yaw + 180.0f;
			p.SetRotation(pitch, fleeYaw);
			p.GetEntity().Move(0, 0, 0.05);
			p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_RUN);
		}

		idleTimer = 0.0f;
		idleState = 0;
	}
	else {
		fleeRoom = NULL;
		fleeWay = NULL;

		if(dist > 8.0f) {
			// Far - follow via waypoints toward player

			// Open doors BEFORE recalculating
			if(way != NULL) {
				Door wpDoor = way.GetDoor();
				if(wpDoor != NULL && !wpDoor.IsOpened() && wpDoor.GetLockState() == 0 && wpDoor.GetEntity().DistanceSquared(pEnt) <= 4.0) {
					wpDoor.Use();
				}
			}
			for(int i = 0; i < 4; i++) {
				Door d = p.GetRoom().GetAdjacentDoor(i);
				if(d != NULL && !d.IsOpened() && d.GetLockState() == 0 && d.GetEntity().DistanceSquared(pEnt) <= 4.0) {
					d.Use();
				}
			}

			botState[0] += dt;
			if(botState[0] >= 1 && (way == NULL || way.GetEntity().Distance(pEnt) < 0.5)) {
				way = world.FindWaypoint(pEnt, tEnt);
				botState[0] = 0.0f;
			}

			if(way != NULL && way.GetEntity().Distance(pEnt) > 0.4) {
				p.GetHead().Point(way.GetEntity());
				float wayYaw = p.GetHead().Yaw(true);
				p.SetRotation(pitch + rand(-8, 8), wayYaw);
				p.GetEntity().Move(0, 0, 0.018);
				p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_WALK);
				p.GetHead().Point(tEnt);
			}
			else {
				p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_IDLE);
			}

			idleTimer = 0.0f;
			idleState = 0;
		}
		else {
			// Mid-range 3-8m - stalk player
			if(watched) {
				p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_IDLE);

				if(headTiltTimer > 1.5f && !wasWatched) {
					headTiltTimer = 0.0f;
					p.SetRotation(rand(-30, 30), yaw + rand(-10, 10));
					p.GetHead().Point(tEnt);
				}
				else if(headTiltTimer > 0.8f && wasWatched) {
					headTiltTimer = 0.0f;
					p.SetRotation(pitch + rand(-10, 10), yaw + rand(-5, 5));
					p.GetHead().Point(tEnt);
				}
			}
			else {
				if(dist > 5.0f) {
					p.SetRotation(pitch + rand(-8, 8), yaw + rand(-5, 5));
					p.GetEntity().Move(0, 0, 0.006);
					p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_WALK);
					idleTimer = 0.0f;
					idleState = 0;
				}
				else {
					if(idleTimer > 5.0f && idleState == 0) {
						idleState = 1;
						idleTimer = 0.0f;
					}

					if(idleState == 0) {
						p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_IDLE);

						if(headTiltTimer > 2.0f) {
							headTiltTimer = 0.0f;
							p.SetRotation(rand(-25, 25), yaw + rand(-12, 12));
							p.GetHead().Point(tEnt);
						}
					}
					else if(idleState == 1) {
						float circleYaw = yaw + (idleTimer > 1.5f ? -90.0f : 90.0f);
						p.SetRotation(pitch + rand(-5, 5), circleYaw);
						p.GetEntity().Move(0, 0, 0.008);
						p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_WALK);
						p.GetHead().Point(tEnt);

						if(idleTimer > 3.0f) {
							idleTimer = 0.0f;
							idleState = rand(0, 2) == 0 ? 2 : 0;
						}
					}
					else if(idleState == 2) {
						if(idleTimer < 1.0f) {
							p.SetRotation(pitch, yaw);
							p.GetEntity().Move(0, 0, 0.05);
							p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_RUN);
						}
						else {
							p.SetNetworkAnimation(PLAYER_MODEL_ANIMATION_IDLE);
							if(idleTimer > 2.0f) {
								idleTimer = 0.0f;
								idleState = 0;
							}
						}
					}
				}
			}
		}
	}

	if(!p.GetEntity().Collided(1))
		p.GetEntity().Translate(0, -0.025, 0);

	wasWatched = watched;
}
