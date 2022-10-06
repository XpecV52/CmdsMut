class CmdsGR extends GameRules;

var Cmds PM;

function ScoreKill(Controller Killer,Controller Killed)
{	
    local Controller cIt;
    local PlayerController pcIt;

	if(KFMonsterController(Killed)!=none)
	{
		if(KFGameType(Level.Game).NumMonsters<=0 && KFGameType(Level.Game).TotalMaxMonsters<=0 && KFStoryGameInfo(Level.Game) == none)
		{	
           if(PM.bAllTraderOpen)
			{	
				PM.BroadcastText("%gAll Traders %ware %bOPEN-UP!!! | %wGet to the %rTraderpod %pquickly");
			}
			else
				PM.BroadcastText("%wGet to the &gTraderpod %pquickly");
        }	
        
		if(KFGameType(Level.Game).NumMonsters<=0 && KFGameType(Level.Game).TotalMaxMonsters<=0)
		{	
            if (PM.bAR)
            {
                for(cIt = Level.ControllerList;cIt != None;cIt = cIt.NextController)
                {
                    pcIt = PlayerController(cIt);
                    if(pcIt != none && cIt.bIsPlayer && cIt.Pawn != None && cIt.Pawn.Health > 0)
                    {
                            PM.GiveAmmo(pcIt);
                            PM.FillupMagazines(pcIt);
                            PM.GiveACandHP("",KFHumanPawn(pcIt.Pawn));
                            PM.CleanupPlayer(KFHumanPawn(pcIt.Pawn));
                    }
                }
                PM.BroadcastText("%gAttributes %ware %bReplenished!%w.");
            }
        }			
	}
    Super.ScoreKill(Killer, Killed);
}
