hTimer <- null;
hPlayer <- null;
hGameText <- null;
bTrail <- true;


enum Flags_t {
    FL_ONGROUND     = 0x1,
    FL_DUCKING      = 0x2
}

function OnTimer()
{
    hPlayer.ValidateScriptScope();
    local pScope = hPlayer.GetScriptScope();

    pScope.angles = pScope.eyes.GetAngles();

    local curVel = hPlayer.GetVelocity().Length2D();

    local onGround = IsGrounded(hPlayer);
    if (onGround) pScope.flags = pScope.flags | Flags_t.FL_ONGROUND;
    else if (!onGround) pScope.flags = pScope.flags & ~Flags_t.FL_ONGROUND;


    // boundMax.z == 72 (standing), boundMax.z = 54 (crouching)
    if (hPlayer.GetBoundingMaxs().z == 54.0) pScope.flags = pScope.flags | Flags_t.FL_DUCKING;
    else pScope.flags = pScope.flags & ~Flags_t.FL_DUCKING;

    // On lift off
    if (!(pScope.flags & Flags_t.FL_ONGROUND) && pScope.prevFlags & Flags_t.FL_ONGROUND) {
        pScope.jumpVel = curVel;
        pScope.jumpPos = hPlayer.GetOrigin();
        pScope.jumpAngle = pScope.angles;
    }

    // On land
    if (!(pScope.prevFlags & Flags_t.FL_ONGROUND) && pScope.flags & Flags_t.FL_ONGROUND)
    {
        local distance = (sqrt(pow(fabs((pScope.jumpPos.x - hPlayer.GetOrigin().x)), 2) + pow(fabs((pScope.jumpPos.y - hPlayer.GetOrigin().y)), 2))) + 34.6; // normal is 32 but +4 to take into account the traces
        local colour = "\x8";

        if (distance >= 235 && distance < 240) colour = "\xB";
        else if (distance >= 240 && distance < 245) colour = "\x4";
        else if (distance >= 245 && distance < 250) colour = "\x2";
        else if (distance >= 250) colour = "\xE";

        if (distance >= 200 && distance < 300) ScriptPrintMessageChatAll(format(" \x8[\x4KZ\x8] %s%s\x8: %s%.1f \x8| \x6%.0f / \x6%.0f \x8Speed",
        colour, pScope.jumpVel < 251 ? "LJ" : "BH", colour, distance, pScope.jumpVel, pScope.jumpMaxVel));

        pScope.jumpVel = 0;
        pScope.jumpMaxVel = 0;
    }

    // If airborne
    if (!(pScope.flags & Flags_t.FL_ONGROUND))
    {
        if (curVel > pScope.jumpMaxVel) pScope.jumpMaxVel = curVel;

        if (bTrail) RenderTrail(hPlayer);
    }

    local message = pScope.jumpVel > 0 ? format("\n(%.0f)", pScope.jumpVel ) : "";

    EntFireByHandle( hGameText, "SetText", format("%.0f%s",curVel, message) , 0.0, null, null);
    EntFireByHandle( hGameText, "Display", "", 0.0, hPlayer, null );

    pScope.prevFlags = pScope.flags;
}

// Called after the entity is spawned
function OnPostSpawn()
{
    hPlayer = Entities.FindByClassname(null, "player");
    hPlayer.ValidateScriptScope();
    hPlayer.__KeyValueFromString("targetname", "@LocalPlayer");
    local pScope = hPlayer.GetScriptScope();

    if (hPlayer != null) {
        pScope.flags <- 0x0;
        pScope.prevFlags <- 0x0;
        pScope.jumpPos <- Vector(0, 0, 0);
        pScope.jumpVel <- 0.0;
        pScope.jumpAngle <- Vector(0, 0, 0);
        pScope.jumpMaxVel <- 0;
        pScope.eyes <- null;
        pScope.angles <- Vector(0, 0, 0);
        pScope.telePos <- Vector(0, 0, 0);
        pScope.teleAng <- Vector(0, 0, 0);
    }

	if( hTimer == null )
	{
		hTimer = Entities.CreateByClassname( "logic_timer" );

        hTimer.__KeyValueFromString( "targetname", "@LogicTimer" );
		hTimer.__KeyValueFromFloat( "refiretime", 0.01 ); // lowest refire time
        // preserve the ent, dont kill after round
        hTimer.__KeyValueFromString( "classname", "soundent" );
		hTimer.ValidateScriptScope();
		local scope = hTimer.GetScriptScope();
		scope.OnTimer <- OnTimer;
		hTimer.ConnectOutput( "OnTimer", "OnTimer" );
		EntFireByHandle( hTimer, "Enable", "", 0, null, null );
	}

    if (hGameText == null)
    {
        hGameText = Entities.CreateByClassname( "game_text" );
        hGameText.__KeyValueFromString("targetname", "@GameText");
        hGameText.__KeyValueFromString("message", "test");
        hGameText.__KeyValueFromFloat("x", -1);
        hGameText.__KeyValueFromFloat("y", 0.8);
        hGameText.__KeyValueFromInt("effect", 0);
        hGameText.__KeyValueFromString("color", "255 255 255");
        hGameText.__KeyValueFromString("color2", "255 255 255");
        hGameText.__KeyValueFromString("fadein", "0");
        hGameText.__KeyValueFromString("fadeout", "0");
        hGameText.__KeyValueFromString("holdtime", "1");
        hGameText.__KeyValueFromString("fxtime", "0");
        hGameText.__KeyValueFromString("channel", "2");
        hGameText.__KeyValueFromString( "classname", "soundent" );
    }

    if ( pScope.eyes == null )
    {
        pScope.eyes = Entities.CreateByClassname( "logic_measure_movement" );
		pScope.eyes.__KeyValueFromInt( "measuretype", 1 );
		pScope.eyes.__KeyValueFromString( "measurereference", "" );
		pScope.eyes.__KeyValueFromString( "measureretarget", "" );
		pScope.eyes.__KeyValueFromFloat( "targetscale", 1.0 );
		local szName = "@LocalPlayerEyes";
		pScope.eyes.__KeyValueFromString( "targetname", szName );
		pScope.eyes.__KeyValueFromString( "targetreference", szName );
		pScope.eyes.__KeyValueFromString( "target", szName );
        pScope.eyes.__KeyValueFromString( "classname", "soundent" );
		EntFireByHandle( pScope.eyes, "SetMeasureReference", szName, 0.0, null, null );
		EntFireByHandle( pScope.eyes, "Enable", "" , 0.0, null, null );
        EntFireByHandle( pScope.eyes, "SetMeasureTarget", "@LocalPlayer", 0.0, null, null );
        pScope.eyes.SetOwner( hPlayer );
    }
}

// many traces 0_0
function IsGrounded(player)
{
    local onGround = false;
    local vPos = player.GetOrigin();
    local vMins = vPos + player.GetBoundingMins();
    local vMaxs = vPos + player.GetBoundingMaxs();

    // 4 corners of the bounding box
    local vC1 = Vector(vMins.x, vMins.y, vMins.z);
    vC1.x = vMaxs.x;
    local vC2 = Vector(vC1.x, vC1.y, vC1.z);
    vC2.y = vMaxs.y;
    local vC3 = Vector(vC2.x, vC2.y, vC2.z);
    vC3.x = vMins.x;
    local vC4 = Vector(vC3.x, vC3.y, vC3.z);
    vC4.y = vMins.y;

    local vals = [vMins, vC1, vC2, vC3, vC4];
    for(local i = 0; i < vals.len()-1; i++ )
    {
        // draw the traces
        // DebugDrawLine(Vector(vals[i].x, vals[i].y, vals[i].z-2.0), vals[i+1], 0, 0, 255, false, 0.1);
        // DebugDrawLine(vPos, Vector(vals[i+1].x, vals[i+1].y, vals[i+1].z-2.0), 0, 255, 255, false, 0.1);

        if(TraceLinePlayersIncluded(Vector(vals[i].x, vals[i].y, vals[i].z-2.0), vals[i+1], player) < 1) onGround = true;
        else if (TraceLinePlayersIncluded(vPos, Vector(vals[i+1].x, vals[i+1].y, vals[i+1].z-2.0), player) < 1) onGround = true;
    }

    return onGround;
}

function RenderTrail(player)
{
    player.ValidateScriptScope();
    local pScope = player.GetScriptScope();
    local vVel = hPlayer.GetVelocity();
    local vPos = player.GetOrigin();
    local r = pScope.flags & Flags_t.FL_DUCKING ? 255 : 0;
    local g = !(pScope.flags & Flags_t.FL_DUCKING) ? 255 : 0;

    vVel.x = (vVel.x / 120.0) + vPos.x;
    vVel.y = (vVel.y / 120.0) + vPos.y;
    vVel.z = pScope.jumpPos.z;

    DebugDrawLine(Vector(vPos.x, vPos.y, pScope.jumpPos.z), vVel, r, g, 0, false, 3.0);
}


function PrintLogo()
{

    printl(".-------------------------------------------------------------------------------------.");
    printl("|                                                                                     |")
    printl("|                                     kz vscript                                      |")
    printl("|                                    made by defuJ                                    |")
    printl("|                                                                                     |")
    printl("|  [info]                                                                             |")
    printl("|  - youtube: https://www.youtube.com/c/defuJ                                         |")
    printl("|  - source : https://github.com/dephoon/CSGO-SMOL-VSCRIPTS/blob/main/src/kz.nut      |")
    printl("|  - steam  : https://steamcommunity.com/id/defuj                                     |")
    printl("|                                                                                     |")
    printl("|  [commands]                                                                         |")
    printl("|  - kz_setpos                                                                        |")
    printl("|  - kz_teleport                                                                      |")
    printl("|  - kz_trail                                                                         |")
    printl("|                                                                                     |")
    printl("'-------------------------------------------------------------------------------------'");
}

function round( v, dp ) {
    local f = pow(10, dp) * 1.0;
    local nV = v * f;
    nV = floor(nV + 0.5)
    nV = (nV * 1.0) / f;

    return nV;
}

function SetTeleport()
{
    hPlayer.ValidateScriptScope();
    local pScope = hPlayer.GetScriptScope()
    pScope.telePos = hPlayer.GetOrigin();
    pScope.teleAng = pScope.angles;
}

function Teleport()
{
    local pScope = hPlayer.GetScriptScope();
    hPlayer.SetVelocity(Vector(0, 0, 0));
    hPlayer.SetOrigin(pScope.telePos);
    hPlayer.SetAngles(pScope.teleAng.x, pScope.teleAng.y, pScope.teleAng.z);
}

function ToggleTrail()
{
    bTrail = !bTrail;
    printl("[KZ] Trail " + (bTrail ? "enabled" : "disabled"));
}

PrintLogo();
OnPostSpawn();
