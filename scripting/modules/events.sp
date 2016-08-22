

public Action ReSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (not bEnabled.BoolValue)
		return Plugin_Continue;

	BaseBoss player = BaseBoss( event.GetInt("userid"), true );
	if ( player and IsClientInGame(player.index) ) {
		SetVariantString(""); AcceptEntityInput(player.index, "SetCustomModel");
		player.SetOverlay("0"); //SetClientOverlay(client, "0");

		if (player.bIsBoss and gamemode.iRoundState < StateEnding and gamemode.iRoundState not_eq StateDisabled)
		{
			if (GetClientTeam(player.index) not_eq BLU)
				player.ForceTeamChange(BLU);
			player.ConvertToBoss();		// in base.sp
		}

		if (not player.bIsBoss and gamemode.iRoundState > StateDisabled and not player.bIsMinion)
		{
			if (GetClientTeam(player.index) not_eq RED)
				player.ForceTeamChange(RED);
			SetPawnTimer( PrepPlayers, 0.2, player );
		}
	}
	return Plugin_Continue;
}
public Action Resupply(Event event, const char[] name, bool dontBroadcast)
{
	if (not bEnabled.BoolValue)
		return Plugin_Continue;

	BaseBoss player = BaseBoss( event.GetInt("userid"), true );
	if ( player and IsClientInGame(player.index) ) {
		SetVariantString(""); AcceptEntityInput(player.index, "SetCustomModel");
		player.SetOverlay("0"); //SetClientOverlay(client, "0");

		if (player.bIsBoss and gamemode.iRoundState < StateEnding and gamemode.iRoundState not_eq StateDisabled)
		{
			if (GetClientTeam(player.index) not_eq BLU)
				player.ForceTeamChange(BLU);
			player.ConvertToBoss();		// in base.sp
		}
	}
	return Plugin_Continue;
}

public Action PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (not bEnabled.BoolValue)
		return Plugin_Continue;

	BaseBoss victim = BaseBoss( event.GetInt("userid"), true );
	BaseBoss fighter = BaseBoss( event.GetInt("attacker"), true );

	//if (fighter.bIsBoss and not player.bIsBoss) // If Boss is killer and victim is not a Boss
	ManageBossKillPlayer(fighter, victim, event);

	//if (fighter.bIsBoss and victim.bIsBoss) //clash of the titans - when both killer and victim are Bosses

	SetPawnTimer(CheckAlivePlayers, 0.2);
	return Plugin_Continue;
}
public Action PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (not bEnabled.BoolValue)
		return Plugin_Continue;

	BaseBoss victim = BaseBoss( event.GetInt("userid"), true );
	int attacker = GetClientOfUserId( event.GetInt("attacker") );
	//int damage = event.GetInt("damageamount");

	// make sure the attacker is valid so we can set him/her as BaseBoss instance
	if ( victim.index is attacker or attacker <= 0 )
		return Plugin_Continue;

	BaseBoss boss = BaseBoss( event.GetInt("attacker"), true );
	ManageHurtPlayer(boss, victim, event);
	//if ( player.bIsBoss )
	//	player.iHealth -= damage;
	return Plugin_Continue;
}
public Action RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (not bEnabled.BoolValue) {
#if defined _steamtools_included
		Steam_SetGameDescription("Team Fortress");
#endif
		return Plugin_Continue;
	}
	if (gamemode.hMusic != null) {
		KillTimer(gamemode.hMusic);
		gamemode.hMusic = null;
	}
	StopBackGroundMusic();
	gamemode.CheckArena(cvarVSH2[PointType].BoolValue);
	gamemode.bPointReady = false;
	GetBossType();	// in handler.sp, check if a boss needs multiple players maybe

	int playing;
	for (int iplay=MaxClients ; iplay ; --iplay) {
		if (not IsValidClient(iplay))	
			continue;

		ManageResetVariables(BaseBoss(iplay));	// in handler.sp
		if (GetClientTeam(iplay) > view_as< int >(TFTeam_Spectator))
			++playing;
	}
	if (GetClientCount() <= 1 or playing < 2) {
		CPrintToChatAll("{olive}[VSH 2]{default} Need more Players to Commence");
		gamemode.iRoundState = StateDisabled;
		SetArenaCapEnableTime(60.0);
		SetPawnTimer(EnableCap, 71.0); //CreateTimer(71.0, Timer_EnableCap, _, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Continue;
	}
	else if ( gamemode.iRoundCount <= 0 and not cvarVSH2[FirstRound].BoolValue )
	{
		CPrintToChatAll("{olive}[VSH2]{default} Normal Round while Everybody is Loading");
		gamemode.iRoundState = StateDisabled;
		SetArenaCapEnableTime(60.0);
		SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 1);
		SetPawnTimer(EnableCap, 71.0); //CreateTimer(71.0, Timer_EnableCap, _, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Continue;
	}
	
	SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0);

	BaseBoss boss = gamemode.FindNextBoss();
	if (boss.index <= 0) {
		CPrintToChatAll("{olive}[VSH 2]{default} Boss client index was Invalid. Need more Players to Commence");
		gamemode.iRoundState = StateDisabled;
		SetControlPoint(true);
		return Plugin_Continue;
	}
	else if ( gamemode.hNextBoss ) {
		boss = gamemode.hNextBoss;
		gamemode.hNextBoss = SPNULL;
	}

	// Got our boss, let's prep him/her.
	boss.bSetOnSpawn = true;
	boss.iType = gamemode.iSpecial;
	ManageOnBossSelected(boss);	// Setting this here so we can intercept Boss type and other info
	boss.ConvertToBoss();
	gamemode.iSpecial = -1;

	if (GetClientTeam(boss.index) is RED)
		boss.ForceTeamChange(BLU);

	BaseBoss player;
	for (int i=MaxClients ; i ; --i) {
		if (not IsValidClient(i) or GetClientTeam(i) <= int(TFTeam_Spectator))
			continue;

		player = BaseBoss(i);
		if (player.bIsBoss)
			continue;

		if (GetClientTeam(i) is BLU)
			player.ForceTeamChange(RED);	// Forceteamchange already does respawn by itself
	}
	gamemode.iRoundState = StateStarting;	// We got players and a valid boss, set the gamestate to Starting
	SetPawnTimer(RoundStartPost, 9.1);		// in handler.sp
	SetPawnTimer(ManagePlayBossIntro, 3.5, boss);	// in handler.sp
	
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_regenerate")) != -1)
		AcceptEntityInput(ent, "Disable");
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_respawnroomvisualizer")) != -1)
		AcceptEntityInput(ent, "Disable");

	ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)
	{
		SetVariantInt(RED);
		AcceptEntityInput(ent, "SetTeam");
		AcceptEntityInput(ent, "skin");
		SetEntProp(ent, Prop_Send, "m_nSkin", 0);
	}

	ent = -1;
	while ((ent = FindEntityByClassname(ent, "mapobj_cart_dispenser")) != -1)
	{
		SetVariantInt(RED);
		AcceptEntityInput(ent, "SetTeam");
		AcceptEntityInput(ent, "skin");
	}
	gamemode.SearchForItemPacks();
	gamemode.iHealthChecks = 0;
	return Plugin_Continue;
}
public Action ObjectDeflected(Event event, const char[] name, bool dontBroadcast)
{
	if (not bEnabled.BoolValue)
		return Plugin_Continue;

	BaseBoss airblaster = BaseBoss( event.GetInt("userid"), true );
	BaseBoss airblasted = BaseBoss( event.GetInt("ownerid"), true );
	int weaponid = GetEventInt(event, "weaponid");
	if (weaponid)	// number lower or higher than 0 is considered "true", learned that in C programming lol
		return Plugin_Continue;

	ManagePlayerAirblast(airblaster, airblasted, event);

	return Plugin_Continue;
}

public Action ObjectDestroyed(Event event, const char[] name, bool dontBroadcast)
{
	if (not bEnabled.BoolValue)
		return Plugin_Continue;

	BaseBoss boss = BaseBoss(event.GetInt("attacker"), true);
	int building = event.GetInt("index");
	int objecttype = event.GetInt("objecttype");

	ManageBuildingDestroyed(boss, building, objecttype);

	return Plugin_Continue;
}

public Action PlayerJarated(Event event, const char[] name, bool dontBroadcast)
{
	if (not bEnabled.BoolValue)
		return Plugin_Continue;

	BaseBoss jarateer = BaseBoss(event.GetInt("thrower_entindex"), true);
	BaseBoss jarateed = BaseBoss(event.GetInt("victim_entindex"), true);
	ManagePlayerJarated(jarateer, jarateed);

	return Plugin_Continue;
}
public Action RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	gamemode.iRoundCount++;
	if (not bEnabled.BoolValue or gamemode.iRoundState is StateDisabled)
		return Plugin_Continue;

	gamemode.iRoundState = StateEnding;
	BaseBoss boss;
	for (int i=MaxClients ; i ; --i) {
		if (not IsValidClient(i))
			continue;
#if defined _tf2attributes_included
		boss = BaseBoss(i);
		TF2Attrib_RemoveByDefIndex(boss.index, 26);
#endif
	}
	StopBackGroundMusic();	// in handler.sp
	if (gamemode.hMusic != null) {
		KillTimer(gamemode.hMusic);
		gamemode.hMusic = null;
	}
	
	BaseBoss bosses[34];
	int index = 0;
	for (int i=MaxClients ; i ; --i, ++index) {		// Loop again for bosses only
		if (not IsValidClient(i))
			continue;

		boss = BaseBoss(i);
		if (not boss.bIsBoss)
			continue;

		if (not IsPlayerAlive(i)) {
			if (GetClientTeam(i) != BLU/*gamemode.iHaleTeam*/)
				boss.ForceTeamChange(BLU);
		}
		else bosses[index] = boss;	// Only living bosses are counted
	}
	ManageRoundEndBossInfo(bosses);

	// Showcase top damage scores!
	int top[3];
	Damage[0] = 0;
	for (int i=MaxClients ; i ; --i) {	// Too lazy to setup methodmap instances, going to use direct arrays
		if (Damage[i] >= Damage[top[0]])
		{
			top[2]=top[1];
			top[1]=top[0];
			top[0]=i;
		}
		else if (Damage[i] >= Damage[top[1]])
		{
			top[2]=top[1];
			top[1]=i;
		}
		else if (Damage[i] >= Damage[top[2]])
			top[2]=i;
	}
	if (Damage[top[0]] > 9000)
		SetPawnTimer(OverNineThousand, 1.0);	// in stocks.inc

	char score1[PATH], score2[PATH], score3[PATH];
	if (IsValidClient(top[0]) and (GetClientTeam(top[0]) is RED))
		GetClientName(top[0], score1, PATH);
	else {
		Format(score1, PATH, "---");
		top[0]=0;
	}

	if (IsValidClient(top[1]) and (GetClientTeam(top[1]) is RED))
		GetClientName(top[1], score2, PATH);
	else {
		Format(score2, PATH, "---");
		top[1]=0;
	}

	if (IsValidClient(top[2]) and (GetClientTeam(top[2]) is RED))
		GetClientName(top[2], score3, PATH);
	else {
		Format(score3, PATH, "---");
		top[2]=0;
	}
	SetHudTextParams(-1.0, 0.3, 10.0, 255, 255, 255, 255);
	PrintCenterTextAll("");	// Should clear center text
	for (int i=MaxClients ; i ; --i) {
		if (IsValidClient(i) and not (GetClientButtons(i) & IN_SCORE))
		{
			SetGlobalTransTarget(i);
			ShowHudText(i, -1, "Most damage dealt by:\n1)%i - %s\n2)%i - %s\n3)%i - %s\n\nDamage Dealt: %i\nScore for this round: %i", Damage[top[0]], score1, Damage[top[1]], score2, Damage[top[2]], score3, Damage[i], RoundFloat(Damage[i] / 600.0));
		}
	}
	SetPawnTimer(CalcScores, 3.0);	// In vsh2.sp
	return Plugin_Continue;
}
public void OnHookedEvent(Event event, const char[] name, bool dontBroadcast)
{
	BaseBoss(event.GetInt("userid"), true).bInJump = StrEqual(name, "rocket_jump", false);
}
public Action ItemPickedUp(Event event, const char[] name, bool dontBroadcast)
{
	if (not bEnabled.BoolValue or gamemode.iRoundState not_eq StateRunning)
		return Plugin_Continue;

	BaseBoss player = BaseBoss(event.GetInt("userid"), true);
	char item[64]; event.GetString("item", item, sizeof(item));
	ManageBossPickUpItem(player, item);	// In handler.sp

	return Plugin_Continue;
}

public Action UberDeployed(Event event, const char[] name, bool dontBroadcast)
{
	if (not bEnabled.BoolValue)
		return Plugin_Continue;
	
	BaseBoss medic = BaseBoss(event.GetInt("userid"), true);
	BaseBoss patient = BaseBoss(event.GetInt("targetid"), true);
	ManageUberDeploy(medic, patient);	// In handler.sp
	return Plugin_Continue;
}