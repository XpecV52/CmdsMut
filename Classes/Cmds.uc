class Cmds extends Mutator
	Config(Cmds)
	abstract;


var() config bool bAllTraderOpen;	// Alltrader or not
var() config bool bAR;				// auto Replenish all players stuff after a wave acomplished of not
var() config bool bNoDrama;			// slomo switch
var() config bool bAdminOnly;		// forbid other players to use mutate
var() config bool bSoloMode;		// leave only 1 free slot

var() config int minNumPlayers;		// int for zed hp calculation
var bool bLock;

var int nFakes;						// main int which controlls fakes amount
var int ServerSpectatorNum;			// server's spectator slots
var int ReservedPlayerSlots;
var float defaultSpawnRate;
var float currentSpawnRate;
struct SColorTag {
    var string T;
    var byte R, G, B;
};
var array<SColorTag> ColorTags;

var bool bLockOn;
var array<string> PlayerNames;		// detects server lock (mutate lock on)
var bool bRefreshMaxPlayers;
var bool bUseReservedSlots;
var bool bGliderAmmo;
var bool bGliderAmmoFillMags;
var bool bSetNextWave;
var int nextWave;
var bool bSkipWave;
var bool bSkipTrader;
var transient array<KFUseTrigger> DoorKeys;
var bool bDoorsFound;
var bool bDoorsIgnored;

var KFGameType KFGT;
var GameRules pgr;

function PostBeginPlay()
{
	local bool bInitialized;

	if(bInitialized)
		return;
	bInitialized = true;

	KFGT = KFGameType(level.game);
	if(KFGT == none)
	{
		Log("KFGameType not found!!!!!!");
	}

	// keep in mind server's spectator count
	ServerSpectatorNum = KFGT.MaxSpectators;
	// SaveConfig();

	SetTimer(1.0,true);
}

event PreBeginPlay()
{
	local GameRules GR;
    local ShopVolume S;
  
  Super.PreBeginPlay();
	
	if(bAllTraderOpen)
	{
		foreach AllActors(Class'ShopVolume',S)
		{
			S.bAlwaysClosed = false;
			S.bAlwaysEnabled= true;
		}
	}
	GR = spawn(class'CmdsGR');
	CmdsGR(GR).PM = Self;

	if (Level.Game.GameRulesModifiers == None)
      Level.Game.GameRulesModifiers = GR;
	  
	else 
      Level.Game.GameRulesModifiers.AddGameRules(GR);
	SetTimer(5,false);
}

function Timer()
{	
    local Controller cIt;
    local PlayerController pcIt;
    local KFUseTrigger KFTrig;
	
    SetTimer(0.1, True);

	if(bGliderAmmo){
        for(cIt = Level.ControllerList;cIt != None;cIt = cIt.NextController){
            pcIt = PlayerController(cIt);
            if(pcIt != none && cIt.bIsPlayer && cIt.Pawn != None && cIt.Pawn.Health > 0){
                GiveAmmo(pcIt);
                if(bGliderAmmoFillMags)
                    FillupMagazines(pcIt);
            }
        }
    }
	if(bNoDrama){
		KFGT.LastZedTimeEvent = Level.TimeSeconds;
	}

    if(!bDoorsFound){
        defaultSpawnRate = KFGT.KFLRules.WaveSpawnPeriod;
        foreach DynamicActors(class'KFUseTrigger', KFTrig)
            DoorKeys[DoorKeys.Length] = KFTrig;
        bDoorsFound = true;
    }
	if(bRefreshMaxPlayers)
		AdjustPlayerSlots();
	if(KFGT.IsInState('PendingMatch'))
	{
		if(RealPlayers() == 0)
		{
			KFGT.NumPlayers = 0;
			return;
		}

		else
		{
			KFGT.NumPlayers = nFakes + RealPlayers();
			return;
		}
	}

	else if(KFGT.IsInState('MatchInProgress'))
	{
		KFGT.NumPlayers = nFakes + RealPlayers();
		return;
	}

	else if(KFGT.IsInState('MatchOver'))
	{
		KFGT.NumPlayers = RealPlayers();
	}
}


function AdjustPlayerSlots()
{
  bRefreshMaxPlayers = false;

	if(bSoloMode)
	{
		KFGT.MaxPlayers = nFakes + 1;
		return;
	}

	if(bUseReservedSlots)
    KFGT.MaxPlayers = nFakes + ReservedPlayerSlots;
}


function int RealPlayers()
{
	local Controller c;
	local int realPlayersCount;
	
	for( c = Level.ControllerList; c != none; c = c.NextController )
		if ( c.IsA('PlayerController') && c.PlayerReplicationInfo != none && !c.PlayerReplicationInfo.bOnlySpectator )
			realPlayersCount++;

	return realPlayersCount;
}


function int AlivePlayersAmount()
{
	local Controller c;
	local int alivePlayersCount;

	for( c = Level.ControllerList; c != none; c = c.NextController )
		if( c.IsA('PlayerController') && c.Pawn != none && c.Pawn.Health > 0 )
			alivePlayersCount ++;

	return alivePlayersCount;
}


function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
  local KFMonster monster;
	local int alivePlayersCount;

  monster = KFMonster(Other);
	if(monster != none)
	{
		alivePlayersCount = AlivePlayersAmount();
		if (alivePlayersCount < minNumPlayers)
		{
			monster.Health *= hpScale(monster.PlayerCountHealthScale) / monster.NumPlayersHealthModifer();
			monster.HealthMax = monster.Health;
			monster.HeadHealth *= hpScale(monster.PlayerNumHeadHealthScale) / monster.NumPlayersHeadHealthModifer();

			monster.MeleeDamage /= 0.75;
			monster.ScreamDamage /= 0.75;
			monster.SpinDamConst /= 0.75;
			monster.SpinDamRand /= 0.75;
		}
	}
	return true;
}


function float hpScale(float hpScale)
{
	return 1.0 + (minNumPlayers - 1) * hpScale;
}


function array<string> SplitString(string inputString, string div)
{
	local array<string> parts;
	local bool bEOL;
	local string tempChar;
	local int preCount, curCount, partCount, strLength;
	strLength = Len(inputString);
	if(strLength == 0)
		return parts;
	bEOL = false;
	preCount = 0;
	curCount = 0;
	partCount = 0;

	while(!bEOL)
	{
		tempChar = Mid(inputString, curCount, 1);
		if(tempChar != div)
			curCount ++;
		else
		{
			if(curCount == preCount)
			{
				curCount ++;
				preCount ++;
			}

			else
			{
				parts[partCount] = Mid(inputString, preCount, curCount - preCount);
				partCount ++;
				preCount = curCount + 1;
				curCount = preCount;
			}
		}

		if(curCount == strLength)
		{
			if(preCount != strLength)
				parts[partCount] = Mid(inputString, preCount, curCount);
			bEOL = true;
		}
	}
	return parts;
}


function bool CheckAdmin(PlayerController Sender)
{
	if ( (Sender.PlayerReplicationInfo != none && Sender.PlayerReplicationInfo.bAdmin) || Level.NetMode == NM_Standalone || Level.NetMode == NM_ListenServer )
		return true;

	SendMessage(Sender, "%wRequires %rADMIN %wprivileges!");
	return false;
}


function Mutate(string MutateString, PlayerController Sender)
{
	local int i,zedHP;
	local array<String> wordsArray;
	local String command, mod;
	local array<String> modArray;
    local float weldStr;
    local string Name;
    local KFHumanPawn PlayerPawn;
    local Controller cIt;
    local PlayerController pcIt;

	if(bAdminOnly)
	{
		if(!CheckAdmin(Sender))
			return;
	}

	else
	{
		if(Sender.PlayerReplicationInfo.bOnlySpectator && !CheckAdmin(Sender))
			return;
	}

	wordsArray = SplitString(MutateString, " ");
	if(wordsArray.Length == 0)
		return;

	command = wordsArray[0];
	if(wordsArray.Length > 1){
		mod = wordsArray[1];
		
		for (i = 2; i < wordsArray.length; i += 1) 
		{
			if (wordsArray[i] != "") 
			{
				mod = mod @ wordsArray[i];
			}
		}
		}
	else
		mod = "";

	i = 0;
	while(i + 1 < wordsArray.Length || i < 10)
	{
		if(i + 1 < wordsArray.Length)
			modArray[i] = wordsArray[i+1];
		else
			modArray[i] = "";
		i ++;
	}

	if(command ~= "HELP" || command ~= "HLP" || command ~= "HALP")
	{
		SendMessage(Sender, "%w[--%rMutator Cmds%w--]%w");
		SendMessage(Sender, "%g[01] - [Mutate HELP] %w- (%pShow Commands Details%w)");
		SendMessage(Sender, "%g[02] - [Mutate STATUS] %w- (%pShow CurGameStatus%w)");
		SendMessage(Sender, "%g[03] - [Mutate SKIP/TT] %w- (%pSkip Trader%w)");
		SendMessage(Sender, "%g[04] - [Mutate TT <Num>] %w- (%pSet Trader time, 6<Num<=3600%w)");
		SendMessage(Sender, "%g[05] - [Mutate FAKE <Num>] %w- (%pSet FakedPlayers, 0<=Num<=20%w)");
		SendMessage(Sender, "%g[06] - [Mutate HP <Num>] %w- (%pSet MinZed HP, 1<=Num<=20%w)");
		SendMessage(Sender, "%g[07] - [Mutate FW <Num>] %w- (%pSet Wavenum%w)");
		SendMessage(Sender, "%g[08] - [Mutate SR <Num>] %w- (%pSet Zed SpawnRate, Float<Num>,eg - 0.5%w)");
		SendMessage(Sender, "%g[09] - [Mutate CN] %w- (%pChange thy Name%w)");
		SendMessage(Sender, "%g[10] - [Mutate LOCK <Num>] %w- (%pLock or Set CurPlayerSlots, Num>=0%w)");
		SendMessage(Sender, "%g[11] - [Mutate SPEC <Num>] %w- (%pDisable or Set CurSpectatorSlots, Num>=0%w)");
		SendMessage(Sender, "%g[12] - [Mutate ZT ON/OFF] %w- (%pEnable/Disable Zed-Time%w)");
		SendMessage(Sender, "%g[13] - [Mutate LDS ON/OFF] %w- (%pZeds won't attack the welded doors%w)");
		SendMessage(Sender, "%g[14] - [Mutate WELD ON/OFF] %w- (%pWeld/UnWeld the Doors%w)");
		SendMessage(Sender, "%g[15] - [Mutate RDS] %w- (%pRespawn the brokenDoors%w)");
		SendMessage(Sender, "%g[16] - [Mutate SOLO ON/OFF] %w- (%pEnable Solo Mode or Not, same as Mutate Lock 1%w)");
		SendMessage(Sender, "%g[17] - [Mutate RP] %w- (%pClear all Zeds and Respawn All Dead Players, even though wiped out%w)");
		SendMessage(Sender, "%g[18] - [Mutate WIPE] %w- (%pClear CurWaveZeds%w)"); 
		SendMessage(Sender, "%g[19] - [Mutate GA ON/OFF] %w- (%pGliderAmmo on/off, %rRequire ADMIN!!!%w)");
		SendMessage(Sender, "%g[20] - [Mutate FILL/MUTATE FILL ALL] %w- (%pReplenish your/all player Armor,HP,Ammo,Mag, %rRequire ADMIN!!!%w)");
		SendMessage(Sender, "%g[21] - [Mutate AR/AUTOREPLENISH] %w- (%pReplenish all Armor,HP,Ammo,Mag, %rRequire ADMIN!!!%w)");
		SendMessage(Sender, "%g[22] - [Mutate FILL] %w- (%pReplenish all Armor,HP,Ammo,Mag, %rRequire ADMIN!!!%w)");
		SendMessage(Sender, "%g[23] - [Mutate ADMIN ON/OFF] %w- (%pWhether to close the command's ADMIN authority or not (only 1-18) , %rRequire ADMIN!!!%w)");
	}

	else if(command ~= "GLIDERAMMO" || command ~= "GA"){
		if(!CheckAdmin(Sender))
			return;
        if(mod ~= "ON" || mod ~= "")
		{	
			bAdminOnly = true;
            GliderAmmo(true);
			}
        else if(mod ~= "OFF")
		{	
			bAdminOnly = true;
            GliderAmmo(false);
			}
    }

	else if(command ~= "TRADER"||command ~="TT"){
		if(!KFGT.bWaveInProgress && KFGT.WaveNum <= KFGT.FinalWave && KFGT.WaveCountDown > 1)
				{
					if(mod == "")
					{
						SkipTrader();
					}
					else if(int(mod) <6)
					{
						BroadcastText("U TYPED THE %rWRONG NUMBER, SUCKERS! %gNum %wis in %b[6,3600]%w", False);
					}
					else if(int(mod) >= 6 && int(mod) <= 3600)
					{
						KFGT.WaveCountDown = int(mod);
						if (InvasionGameReplicationInfo(KFGT.GameReplicationInfo) != none)
				InvasionGameReplicationInfo(KFGT.GameReplicationInfo).waveNumber = KFGT.waveNum;
					BroadcastText("%gTrader time %wis changed to %b"$int(mod)$" s!", true);
					}
					else
					{
						KFGT.WaveCountDown = 3600;
						BroadcastText("%gTrader time %wis changed to %b3600 s!", False);
					}
				}
				mod = "";
	}

	else if(command ~= "WAVE"||command ~= "FW"){
			SetWave(Int(mod));
	}

	else if(command ~= "WELD")
	{
        if(mod ~= "ON" || mod ~= "")
		{
			weldStr = 100.0;
			WeldDoors(weldStr,true);
			BroadcastText("%gDoors %ware %bRewelded!");
			}
		else if (mod ~= "OFF")
		{
			weldStr = -1;
			WeldDoors(weldStr,true);
			BroadcastText("%gDoors %ware %bUnwelded!");
			}
    }

	else if(command ~= "LOCKDOORS"||command ~= "LDS"){
		if(mod ~= "ON" || mod ~= "")
		{
            IgnoreDoors(true);
			BroadcastText("%gZeds won't Attack the WeldedDoors!");
			}
        else if(mod ~= "OFF")
		{
            IgnoreDoors(false);
			BroadcastText("%gZeds will Attack the WeldedDoors!");
			}
	}

	else if(command ~= "RESPAWNDOORS"||command ~= "RDS"){
		SpawnDoors();
		BroadcastText("%g All broken doors %ware %bRespawned!");
	}

	else if(command ~= "FAKED" || command ~= "FAKE" || command ~= "FAKES")
	{
		if(Int(mod) >= 0 && Int(mod) <= 20)
		{
			nFakes = Int(mod);
			if(bLockOn)
				KFGT.MaxPlayers = RealPlayers() + nFakes;
			BroadcastText("%gFaked players %wis set to %b"$Int(mod)$"%w ==>%b "$Int(mod)+1$" %wx %gtotalZeds", true);
		}
	}

	else if(command ~= "HEALTH" || command ~= "HP")
	{
		zedHP = Clamp(Int(mod),1,20);

		minNumPlayers = zedHP;
		BroadcastText("%gZeds minimal health %wis forced to %b"$zedHP, true);
	}
	else if(command ~= "CHANGENAME" || command ~= "CN")
        {
            Name = mod;
            if(Name == "")
            {
                Name = PlayerNames[Rand(PlayerNames.Length)];
            }

            if((Sender.PlayerReplicationInfo != none && Sender.PlayerReplicationInfo.bAdmin) || Level.NetMode == NM_Standalone || Level.NetMode == NM_ListenServer)
            {
                SendMessage(Sender, "%gYou %whave changed your name to %b" $ Name $ "%w.");
            }
            else/* (!Sender.PlayerReplicationInfo.bSilentAdmin) */
            {
                BroadcastText("%g" $ Sender.PlayerReplicationInfo.PlayerName$ " %whas changed his name to %b" $ Name $ "%w.");
            }
            Sender.PlayerReplicationInfo.PlayerName = Name;
        }

  else if(command ~= "SOLO")
  {
    if(mod ~= "ON" || mod ~= "")
		{
			bSoloMode = true;
      	SaveConfig();
			BroadcastText("%gSolo mode %wis %b"$mod, true);
		}

		else if(mod ~= "OFF")
		{
			bSoloMode = false;
      SaveConfig();
			BroadcastText("%gSolo mode %wis %b"$mod, true);
		}
  }


	else if(command ~= "LOCK" || command ~= "PLAYER" || command ~= "PLAYERS" || command ~= "SLOT")
	{
		if(mod ~= "ON" || mod ~= "")
		{
			KFGT.MaxPlayers = RealPlayers() + nFakes;
			bLockOn = true;
			BroadcastText("%gServer %wis %bLocked!", true);
		}

		else if(mod ~= "OFF")
		{
			KFGT.MaxPlayers = 6;
			bLockOn = false;
			BroadcastText("%gServer %wis %bUnlocked!", true);
		}

		else
		{
			KFGT.MaxPlayers = Int(mod);
			BroadcastText("%gPlayer slots %ware set to %b"$Int(mod), true);
		}
	}

	else if(command ~= "SKIP" || command ~= "SKP")
	{
		SkipTrader();
	}

	else if(command ~= "SPEC" || command ~= "SPECS" || command ~= "SPECTATOR" || command ~= "SPECTATORS")
	{
		if(mod ~= "DEFAULT")
		{
			KFGT.MaxSpectators = ServerSpectatorNum;
			BroadcastText("%gSpectator slots %ware restored to %bdefault!", true);
		}

		else if(mod ~= "OFF")
		{
			KFGT.MaxSpectators = 0;
			BroadcastText("%gSpectator slots %ware %bdisabled!", true);
		}

		else
		{
			KFGT.MaxSpectators = Int(mod);
			BroadcastText("%gSpectator slots %ware set to %b"$Int(mod), true);
		}
	}

	else if(command ~= "DRAMA" || command ~= "SLOMO" || command ~= "ZT")
	{
		if(mod ~= "ON" || mod ~= "")
		{
			bNoDrama = false;
			BroadcastText("%gZED-Time %bEnabled", true);
		}

		else if(mod ~= "OFF")
		{
			bNoDrama = true;
			BroadcastText("%gZED-Time %bDisabled", true);
		}
	}

	else if(command ~= "ADMINONLY" || command ~= "ADMIN")
	{
		if(!CheckAdmin(Sender))
			return;

		if(mod ~= "ON" || mod ~= "")
		{
			bAdminOnly = true;
		SaveConfig();
			BroadcastText("%wOnly %rAdmins %wcan use commands!", true);
		}

		else if(mod ~= "OFF")
		{
			bAdminOnly = false;
		SaveConfig();
			BroadcastText("%gAll players %wcan use commands!", true);
		}
	}

	else if(command ~= "SAVE")
	{
		if(!CheckAdmin(Sender))
			return;
		SaveConfig();
		SendMessage(Sender, "%rConfig is saved!");
	}

	else if (command ~= "Wipe")
	{
		WipeAll();
		BroadcastText("%gAll Faggots %ware %bWIPED!",true);
	}

	else if(command ~= "SPAWNRATE" || command ~= "sr"){
        if(mod ~= "")
            SetSpawnRate(-1.0);
        else
            SetSpawnRate(Float(mod));
    }
	
    /* else if(command ~= "AMMO" || command ~= "AM")
	{	
		if(!CheckAdmin(Sender))
			return;
		GiveAmmo(Sender);
		FillupMagazines(Sender);
		BroadcastText("%w" $ Sender.PlayerReplicationInfo.PlayerName$ "  %gAmmo %w&& %gMag %ware %bReplenished!",true);
	}

	else if(command ~= "ACHP"){
		if(!CheckAdmin(Sender))
			return;
        PlayerPawn = KFHumanPawn(Sender.Pawn);
        if(KFHumanPawn(Sender.Pawn) != none)
            GiveACandHP(mod, PlayerPawn); 
			BroadcastText("%w" $ Sender.PlayerReplicationInfo.PlayerName$ "   %gAC %w&& %gHP %ware %bReplenished!");
    }
 */
	else if(command ~= "FILL")
	{	
		if(!CheckAdmin(Sender))
			return;
		if(mod ~= "")
		{
			GiveAmmo(Sender);
			FillupMagazines(Sender);
			PlayerPawn = KFHumanPawn(Sender.Pawn);
			if(KFHumanPawn(Sender.Pawn) != none)
				GiveACandHP(mod, PlayerPawn); 
				CleanupPlayer(PlayerPawn);
			BroadcastText("%w"$Sender.PlayerReplicationInfo.PlayerName$"'s %gstuff %ware %bReplenished!");
		}

		else if(mod ~= "ALL")
		{
			for(cIt = Level.ControllerList;cIt != None;cIt = cIt.NextController)
			{
				pcIt = PlayerController(cIt);
				if(pcIt != none && cIt.bIsPlayer && cIt.Pawn != None && cIt.Pawn.Health > 0)
				{
					GiveAmmo(pcIt);
					FillupMagazines(pcIt);
					GiveACandHP("",KFHumanPawn(pcIt.Pawn));
					CleanupPlayer(KFHumanPawn(pcIt.Pawn));
				}
			}
			BroadcastText("%wAll %gstuff %ware %bReplenished!");
		}
	}

	
	else if (command ~= "AutoReplenish"||command ~= "AR")
	{
		if(mod ~= "ON" || mod ~= "")
		{
			bAR=True;
			SaveConfig();
        	BroadcastText("%gAttributes %wAuto-%bReplenished %bEnabled.");
		}
		else if(mod ~= "OFF")
		{
			bAR=False;
			SaveConfig();
        	BroadcastText("%gAttributes %wAuto-%bReplenished %bDisabled..");
		}
	}

	
	else if (command ~= "ALLREADY"||command ~= "FRA")
	{
		for( cIt = Level.ControllerList; cIt != None; cIt = cIt.nextController )
		{
			if( cIt.IsA('PlayerController'))
			{
				cIt.PlayerReplicationInfo.bReadyToPlay=true;
			}
		}
		BroadcastText("%gAll pendings %ware forced to be %bReady.");
	}

	
	else if(command ~= "RESURRECT" || command ~= "RP"){
        	
		if(ResurrectPlayers() > 0)
		{	
			KFGameReplicationInfo(Level.GRI).EndGameType = 0;
			if(KFGT.IsInState('MatchOver'))
			{
				KFGT.GotoState('MatchInProgress');
			}
			WipeAll();
			ResurrectPlayers();
			BroadcastText("All %gFUCKING DEADs %ware %bResurrected!");
		}
		else 
		{
			BroadcastText("All the %gplayers %ware still %brlive%w.");
		}
    }

	else if(command ~= "STATUS")
	{
		SendMessage(Sender, "%rU, THE FREAKING BADASS!!!");
		SendMessage(Sender, "%gAdminOnly: %b"$bAdminOnly);
		SendMessage(Sender, "%gAll trader open: %b"$bAllTraderOpen);
		SendMessage(Sender, "%gAuto replenish: %b"$bAR);
		SendMessage(Sender, "%gCur Player Slots: %b"$KFGT.MaxPlayers);
		SendMessage(Sender, "%gCur Real Players: %b"$RealPlayers());
		SendMessage(Sender, "%gCur Spectator Slots: %b"$KFGT.MaxSpectators);
		SendMessage(Sender, "%gDef Spectator Slots: %b"$ServerSpectatorNum);
		SendMessage(Sender, "%gSolo Mode: %b"$bSoloMode);
		SendMessage(Sender, "%gSpawn Rate: %b"$currentSpawnRate);
		SendMessage(Sender, "%gFakes: %b"$nFakes);
		SendMessage(Sender, "%gZeds Minimal Health: %b"$minNumPlayers);
		SendMessage(Sender, "%gZED-Time Disable: %b"$bNoDrama);
	}

  else if(command ~= "ReservedSlots" || command ~= "rs")
	{
		if(!CheckAdmin(Sender))
			return;
		EditConfigSlots(Sender, mod);
	}

  else if(command ~= "ConfigFakes" || command ~= "cf")
	{
		if(!CheckAdmin(Sender))
			return;
		EditConfigFakes(Sender, mod);
	}

	Super.Mutate(MutateString, Sender);
}



// copy-pasted from ScrnPlayerController for easy access
static final function string ColorString(string s, byte R, byte G, byte B)
{
    return chr(27)$chr(max(R,1))$chr(max(G,1))$chr(max(B,1))$s;
}

static final function string ColorStringC(string s, color c)
{
    return chr(27)$chr(max(c.R,1))$chr(max(c.G,1))$chr(max(c.B,1))$s;
}

static final function string StripColor(string s)
{
    local int p;

    p = InStr(s,chr(27));
    while ( p>=0 )
    {
        s = left(s,p)$mid(S,p+4);
        p = InStr(s,Chr(27));
    }

    return s;
}

// returns first i amount of characters excluding escape color codes
static final function string LeftCol(string ColoredString, int i)
{
    local string s;
    local int p, c;

    if ( Len(ColoredString) <= i )
        return ColoredString;

    c = i;
    s = ColoredString;
    p = InStr(s,chr(27));
    while ( p >=0 && p < i ) {
        c+=4; // add 4 more characters due to color code
        s = left(s, p) $ mid(s, p+4);
        p = InStr(s,Chr(27));
    }

    return Left(ColoredString, c);
}


simulated function string StripColorTags(string ColoredText)
{
    local int i;
    local string s;

    s = ColoredText;
    ReplaceText(s, "^p", "");
    ReplaceText(s, "^t", "");
    for ( i=0; i<ColorTags.Length; ++i ) {
        ReplaceText(s, ColorTags[i].T, "");
    }

    return s;
}


function SkipTrader()
{
	if (!KFGT.bWaveInProgress && KFGT.waveNum <= KFGT.finalWave && KFGT.waveCountDown > 1)
	{
		KFGT.waveCountDown = 1;
		if (InvasionGameReplicationInfo(KFGT.GameReplicationInfo) != none)
			InvasionGameReplicationInfo(KFGT.GameReplicationInfo).waveNumber = KFGT.waveNum;
		BroadcastText("%gTrader time %wis %bSkipped!", true);
	}
}

function SetSpawnRate(float rate){
    currentSpawnRate = rate;
    if(rate < 0){
        rate = defaultSpawnRate;
        currentSpawnRate = -1.0;
    }
    KFGT.KFLRules.WaveSpawnPeriod = rate;
    BroadcastText("%gZed spawn rate %wchanged to%b"@String(rate)$"%w, default:%r"@String(defaultSpawnRate));
}

function GiveACandHP(string armorType, KFHumanPawn PlayerPawn/* , bool bSafeGuardGift */){
    PlayerPawn.ShieldStrength = 100;
    PlayerPawn.Health = 100;
    PlayerPawn.HealthMax = 100;
}

function GiveAmmo(PlayerController PC){
    local Inventory Inv;
    local KFHumanPawn PlayerPawn;
    local KFAmmunition AmmoToUpdate;
    local KFPlayerReplicationInfo KFPRI;
    local class<KFVeterancyTypes> PlayerVeterancy;
    PlayerPawn = KFHumanPawn(PC.Pawn);
    if(PlayerPawn == none)
        return;
    KFPRI = KFPlayerReplicationInfo(PlayerPawn.PlayerReplicationInfo);
    if(KFPRI != none)
        PlayerVeterancy = KFPRI.ClientVeteranSkill;
    for(Inv = PlayerPawn.Inventory; Inv != None; Inv = Inv.Inventory){
        AmmoToUpdate = KFAmmunition(Inv);
        if(AmmoToUpdate != None && AmmoToUpdate.AmmoAmount < AmmoToUpdate.MaxAmmo){
            if(PlayerVeterancy != none){
                AmmoToUpdate.MaxAmmo = AmmoToUpdate.default.MaxAmmo;
                AmmoToUpdate.MaxAmmo = float(AmmoToUpdate.MaxAmmo) * PlayerVeterancy.static.AddExtraAmmoFor(KFPRI, AmmoToUpdate.class);
            }
            AmmoToUpdate.AmmoAmount = AmmoToUpdate.MaxAmmo;
        }
    }
}

function FillupMagazines(PlayerController PC){
    local Inventory Inv;
    local KFHumanPawn PlayerPawn;
    local KFWeapon WeaponToFill;
    PlayerPawn = KFHumanPawn(PC.Pawn);
    if(PlayerPawn == none)
        return;
    for(Inv = PlayerPawn.Inventory; Inv != none; Inv = Inv.Inventory){
        WeaponToFill = KFWeapon(Inv);
        if(WeaponToFill != none){
            WeaponToFill.MagAmmoRemaining = WeaponToFill.MagCapacity;
        }
    }
}

function SpawnDoors(){
    local int i, j;
    local KFUseTrigger key;
	
    if(!bDoorsFound)
        return;
    for (i = 0;i < DoorKeys.Length;i ++){
        key = DoorKeys[i];
        for(j = 0;j < key.DoorOwners.Length;j ++)
            if(key.DoorOwners[j].bDoorIsDead){
                key.DoorOwners[j].RespawnDoor();
		}
    }
}

function WeldDoors(float fStrenght, bool bSkipUnsealed){
    local int i, j;
    local KFUseTrigger key;
    local float newWeldValue;
    if(!bDoorsFound)
        return;
    for (i = 0;i < DoorKeys.Length;i ++){
        key = DoorKeys[i];
        if(!bSkipUnsealed || DoorKeys[i].WeldStrength > 0)
            DoorKeys[i].WeldStrength = DoorKeys[i].MaxWeldStrength * fStrenght / 100.0;
        for(j = 0;j < key.DoorOwners.Length;j ++)
            if(!bSkipUnsealed || key.DoorOwners[j].bSealed){
                newWeldValue = key.DoorOwners[j].MaxWeld * fStrenght / 100.0;
                key.DoorOwners[j].SetWeldStrength(newWeldValue);
            }
    }
}

function IgnoreDoors(bool bDoIgnore){
    local int i, j;
    local KFUseTrigger key;
    if(!bDoorsFound)
        return;
    for(i = 0;i < DoorKeys.Length;i ++){
        key = DoorKeys[i];
        for(j = 0;j < key.DoorOwners.Length;j ++){
            if(!bDoIgnore || (bDoIgnore && key.DoorOwners[j].bSealed)){
                key.DoorOwners[j].bZombiesIgnore = bDoIgnore;
                key.DoorOwners[j].bBlockDamagingOfWeld = bDoIgnore;
            }
            if(bDoIgnore && key.DoorOwners[j].bSealed)
                key.DoorOwners[j].DoorPathNode.bBlocked = true;
            else
                key.DoorOwners[j].DoorPathNode.bBlocked = false;
        }
    }
}

function GliderAmmo(bool bActivate){
    if(bGliderAmmo == bActivate || bGliderAmmoFillMags == bActivate)
        return;
    if(bActivate){
        bGliderAmmo = true;
        bGliderAmmoFillMags = true;
        BroadcastText("%gGlider Ammo %wis %bon%w");
    }
    else{
        bGliderAmmo = false;
        bGliderAmmoFillMags = false;
        BroadcastText("%gGlider Ammo %wis %boff%w");
    }
}

function SetWave(int mod){
    local int currentWave;

	
	KFGameReplicationInfo(Level.GRI).EndGameType = 0;
	if(KFGT.IsInState('MatchOver'))
	{
		KFGT.GotoState('MatchInProgress');
	}
	WipeAll();
	KFGameType(Level.Game).TotalMaxMonsters=0;
    currentWave = mod;
    mod = Clamp(mod - 1, 0, KFGT.FinalWave);
	if(KFGT.bWaveInProgress)
	{
		WipeAll();
		KFGT.WaveNum = mod-1;
    	BroadcastText("%gWaveNum %wis set to %b"@String(mod+1));
	}
    else if(KFGT.bTradingDoorsOpen)
	{
        KFGT.WaveNum = mod;
    	BroadcastText("%gWaveNum %wis set to %b"@String(mod+1));
		}
    else{
		WipeAll();
		BroadcastText("%rU Wiped the CurWave Trash, %wTry this shit in %gTraderTime.");
    }
}

function int ResurrectPlayers()
{
    local Controller C;
    local PlayerController PC;
    local bool bWaveState;
    local int AliveCount;

    
    for(C = Level.ControllerList;C != none;C = C.nextController)
    {
        if(((C.bIsPlayer && C.PlayerReplicationInfo != none) && !C.PlayerReplicationInfo.bOnlySpectator) && C.Pawn == none)
        {
            AliveCount++ ;
        }
    }
    if(AliveCount <= 0)
    {
        return 0;
    }
    bWaveState = KFGT.bWaveInProgress;
    KFGT.Disable('Timer');
    KFGT.bWaveInProgress = false;
    
    for(C = Level.ControllerList;C != none;C = C.nextController)
    {
        if(((C.bIsPlayer && C.PlayerReplicationInfo != none) && !C.PlayerReplicationInfo.bOnlySpectator) && C.Pawn == none)
        {
            PC = PlayerController(C);
            PC.PlayerReplicationInfo.bOutOfLives = false;
            PC.PlayerReplicationInfo.NumLives = 0;
            PC.GotoState('PlayerWaiting');
            PC.SetViewTarget(PC);
            PC.ClientSetBehindView(false);
            PC.bBehindView = false;
            PC.ClientSetViewTarget(PC.Pawn);
            KFGT.RestartPlayer(PC);
        }
    }
    KFGT.bWaveInProgress = bWaveState;
    KFGT.Enable('Timer');
    return AliveCount;
}


function CleanupPlayer(KFHumanPawn PlayerPawn){
    PlayerPawn.bBurnified = false;
    PlayerPawn.BileCount = 0;
    PlayerPawn.BurnDown = 0;
    PlayerPawn.RemoveFlamingEffects();
    PlayerPawn.StopBurnFX();
}

function WipeAll()
{
	local array <KFMonster> Monsters; 
  	local KFMonster M;
  	local int i;
    	foreach DynamicActors(class 'KFMonster', M)
    	{
        	if(M.Health > 0 && !M.bDeleteMe)
        	{
            	Monsters[Monsters.length] = M;
        	}
        	for ( i=0; i<Monsters.length; ++i )
        	{
          		Monsters[i].Died(Monsters[i].Controller, class'DamageType', Monsters[i].Location);
        	}
    	}
		KFGameType(Level.Game).TotalMaxMonsters=0;
}


function EditConfigFakes(PlayerController pc, string mod)
{
  SendMessage(pc, "%wThis is meant to be used in %bCustom%w mode!");
}


function EditConfigSlots(PlayerController pc, string mod)
{
  SendMessage(pc, "%wThis is meant to be used in %bCustom%w mode!");
}

function SendMessage(PlayerController pc, coerce string message)
{
	if(pc == none || message == "")
		return;

	if(pc.playerReplicationInfo.PlayerName ~= "WebAdmin" && pc.PlayerReplicationInfo.PlayerID == 0)
		message = StripFormattedString(message);
	else
		message = ParseFormattedLine(message);

	pc.teamMessage(none, message, 'FakedPlayers');
}


function BroadcastText(string message, optional bool bSaveToLog)
{
	local Controller c;

	for(c = level.controllerList; c != none; c = c.nextController)
	{
		if(PlayerController(c) != none)
			SendMessage(PlayerController(c), message);
	}

	if(bSaveToLog)
	{
		message = StripFormattedString(message);
		log("FakedPlayers: "$message);
	}
}


// color codes for messages
static function string ParseFormattedLine(string input)
{
	ReplaceText(input, "%r", chr(27)$chr(200)$chr(1)$chr(1));
	ReplaceText(input, "%g", chr(27)$chr(1)$chr(200)$chr(1));
	ReplaceText(input, "%b", chr(27)$chr(1)$chr(100)$chr(200));
	ReplaceText(input, "%w", chr(27)$chr(200)$chr(200)$chr(200));
	ReplaceText(input, "%y", chr(27)$chr(200)$chr(200)$chr(1));
	ReplaceText(input, "%p", chr(27)$chr(200)$chr(1)$chr(200));
	return input;
}



function string StripFormattedString(string input)
{
	ReplaceText(input, "%r", "");
	ReplaceText(input, "%g", "");
	ReplaceText(input, "%b", "");
	ReplaceText(input, "%w", "");
	ReplaceText(input, "%y", "");
	ReplaceText(input, "%p", "");
	return input;
}


static function FillPlayInfo(PlayInfo PlayInfo)
{
	Super.FillPlayInfo(PlayInfo);

	PlayInfo.AddSetting("SXKCmds", "bAllTraderOpen", "AllTraderOpen", 0, 1, "check");
	PlayInfo.AddSetting("SXKCmds", "bAR", "Attributes auto replenish", 0, 1, "check");
	PlayInfo.AddSetting("Cmds", "bNoDrama", "Disable SloMo", 0, 0, "check");
	PlayInfo.AddSetting("Cmds", "bAdminOnly", "Only Admins can use commands", 0, 0, "check");
	PlayInfo.AddSetting("Cmds", "bSoloMode", "Solo Mode", 0, 0, "check");
	PlayInfo.AddSetting("Cmds", "minNumPlayers", "Mimimal zed health", 0, 1, "Text", "4;0:6", "", False, False);
}


static function string GetDescriptionText(string SettingName)
{
	switch (SettingName)
	{	
		case "bAllTraderOpen":
			return "AllTraderOpen";
		case "bAR":
			return "Attributes auto replenish";
		case "bNoDrama":
			return "Enable/disable ZED-Time";
		case "bAdminOnly":
			return "Only Admins can use commands";
		case "bSoloMode":
			return "Leaves only 1 avialable player slot";
		case "minNumPlayers":
			return "Force minimal health for zeds";
	}

	return Super.GetDescriptionText(SettingName);
}

defaultproperties
{	
	 
     ColorTags( 0)=(T="^0",R=1,G=1,B=1)
     ColorTags( 1)=(T="^1",R=200,G=1,B=1)
     ColorTags( 2)=(T="^2",R=1,G=200,B=1)
     ColorTags( 3)=(T="^3",R=200,G=200,B=1)
     ColorTags( 4)=(T="^4",R=1,G=1,B=255)
     ColorTags( 5)=(T="^5",R=1,G=255,B=255)
     ColorTags( 6)=(T="^6",R=200,G=1,B=200)
     ColorTags( 7)=(T="^7",R=200,G=200,B=200)
     ColorTags( 8)=(T="^8",R=255,G=127,B=0)
     ColorTags( 9)=(T="^9",R=128,G=128,B=128)
 
     ColorTags(10)=(T="^w$",R=255,G=255,B=255)
     ColorTags(11)=(T="^r$",R=255,G=1,B=1)
     ColorTags(12)=(T="^g$",R=1,G=255,B=1)
     ColorTags(13)=(T="^b$",R=1,G=1,B=255)
     ColorTags(14)=(T="^y$",R=255,G=255,B=1)
     ColorTags(15)=(T="^c$",R=1,G=255,B=255)
     ColorTags(16)=(T="^o$",R=255,G=140,B=1)
     ColorTags(17)=(T="^u$",R=255,G=20,B=147)
     ColorTags(18)=(T="^s$",R=1,G=192,B=255)
     ColorTags(19)=(T="^n$",R=139,G=69,B=19)
 
     ColorTags(20)=(T="^W$",R=112,G=138,B=144)
     ColorTags(21)=(T="^R$",R=132,G=1,B=1)
     ColorTags(22)=(T="^G$",R=1,G=132,B=1)
     ColorTags(23)=(T="^B$",R=1,G=1,B=132)
     ColorTags(24)=(T="^Y$",R=255,G=192,B=1)
     ColorTags(25)=(T="^C$",R=1,G=160,B=192)
     ColorTags(26)=(T="^O$",R=255,G=69,B=1)
     ColorTags(27)=(T="^U$",R=160,G=32,B=240)
     ColorTags(28)=(T="^S$",R=65,G=105,B=225)
     ColorTags(29)=(T="^N$",R=80,G=40,B=20)

     bAdminOnly=True
     bAllTraderOpen=True
	 bAR=True
     minNumPlayers=1
	 ReservedPlayerSlots=0
	 nFakes=0
	 bSoloMode=False
	 bLockOn=False
	 bNoDrama=False
	 bUseReservedSlots=False
     bRefreshMaxPlayers=True
     GroupName="KF-CMDMutator"
     FriendlyName="CmdsMut"
     Description="CmdsMut."
}
