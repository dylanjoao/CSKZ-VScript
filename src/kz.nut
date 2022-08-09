hTimer <- null;
hGameUI <- null;
hJumpUI <- null;
hPlayer <- null;

flJumpReset <- 0.0;
flUseReset <- 0.0;

const colourLabel = "'#a9a9a9'";
const colourOn = "'#228B22'";
const colourOff = "'#FFFFFF'";
const colourOL = "'#D2042D'";

enum Buttons_t {
    IN_ATTACK       = 0x001,
    IN_ATTACK2      = 0x002,
    IN_JUMP         = 0x004,
    IN_USE          = 0x008,
    IN_FORWARD      = 0x010,
    IN_BACK         = 0x020,
    IN_MOVELEFT     = 0x040,
    IN_MOVERIGHT    = 0x080,
};

enum Flags_t {
    FL_ONGROUND     = 0x1,
    FL_DUCKING      = 0x2
}

enum Strafes_t {
    ST_NONE         = 0,
    ST_LEFT         = 1,
    ST_RIGHT        = 2
}

function OnTimer()
{
    hPlayer.ValidateScriptScope();
    local pScope = hPlayer.GetScriptScope();

    pScope.prevAngles = pScope.angles;
    pScope.angles = pScope.eyes.GetAngles();

    local curVel = hPlayer.GetVelocity().Length2D();

    local onGround = IsGrounded(hPlayer);
    if (onGround) pScope.flags = pScope.flags | Flags_t.FL_ONGROUND;
    else if (!onGround) pScope.flags = pScope.flags & ~Flags_t.FL_ONGROUND;


    // boundMax.z == 72 (standing), boundMax.z = 54 (crouching)
    if (hPlayer.GetBoundingMaxs().z == 54.0) pScope.flags = pScope.flags | Flags_t.FL_DUCKING;
    else pScope.flags = pScope.flags & ~Flags_t.FL_DUCKING;

    if (round(Time(), 1) == round(flJumpReset, 1)) pScope.buttons = pScope.buttons & ~Buttons_t.IN_JUMP;
    if (round(Time(), 1) == round(flUseReset, 1)) pScope.buttons = pScope.buttons & ~Buttons_t.IN_USE;

    local forwardColour =  pScope.buttons & Buttons_t.IN_FORWARD ? colourOn : colourOff;
    local leftColour = pScope.buttons & Buttons_t.IN_MOVELEFT ? colourOn : colourOff;
    local backColour =  pScope.buttons & Buttons_t.IN_BACK ? colourOn : colourOff;
    local rightColour =  pScope.buttons & Buttons_t.IN_MOVERIGHT ? colourOn : colourOff;
    local jumpColour = pScope.buttons & Buttons_t.IN_JUMP ? colourOn : colourOff;

    local duckColour = pScope.flags & Flags_t.FL_DUCKING ? colourOn : colourOff;

    if (pScope.buttons & Buttons_t.IN_MOVELEFT && pScope.buttons & Buttons_t.IN_MOVERIGHT) {
        leftColour = colourOL;
        rightColour = colourOL;
    }

    if (pScope.buttons & Buttons_t.IN_USE) printl("+use");

    // On lift off
    if (!(pScope.flags & Flags_t.FL_ONGROUND) && pScope.prevFlags & Flags_t.FL_ONGROUND) {
        pScope.jumpVel = curVel;
        pScope.jumpPos = hPlayer.GetOrigin();
        pScope.jumpAngle = pScope.angles;

        // printl(format("%f - %f = %f", fabs(pScope.angles.y), fabs(pScope.prevAngles.y), fabs(pScope.angles.y) - fabs(pScope.prevAngles.y)));
    }

    // On land
    if (!(pScope.prevFlags & Flags_t.FL_ONGROUND) && pScope.flags & Flags_t.FL_ONGROUND)
    {
        local distance = (sqrt(pow(fabs((pScope.jumpPos.x - hPlayer.GetOrigin().x)), 2) + pow(fabs((pScope.jumpPos.y - hPlayer.GetOrigin().y)), 2))) + 36.0; // normal is 32 but +4 to take into account the traces
        local colour = "\x8";

        if (distance >= 235 && distance < 240) colour = "\xB";
        else if (distance >= 240 && distance < 245) colour = "\x4";
        else if (distance >= 245 && distance < 250) colour = "\x2";
        else if (distance >= 250) colour = "\xE";

        if (distance >= 200 && distance < 300) ScriptPrintMessageChatAll(format(" \x8[\x4KZ\x8] %s%s\x8: %s%.1f \x8| \x6%.0f / \x6%.0f \x8Speed",
        colour, pScope.jumpVel < 251 ? "LJ" : "BH", colour, distance, pScope.jumpVel, pScope.jumpMaxVel));

        pScope.jumpStrafes = 0;
        pScope.jumpVel = 0;
        pScope.jumpMaxVel = 0;
    }

    // If airborne
    if (!(pScope.flags & Flags_t.FL_ONGROUND))
    {
        if (curVel > pScope.jumpMaxVel) pScope.jumpMaxVel = curVel;

        RenderTrail(hPlayer);
    }

    ScriptPrintMessageCenterAll(format(
    "%f %.0f (%.0f)\n" +
    "<font color=%s>W</font>" +
    "<font color=%s>A</font>" +
    "<font color=%s>S</font>" +
    "<font color=%s>D</font>   " +
    "<font color=%s>C</font>   <font color=%s>J</font>",
    hPlayer.GetOrigin().z, curVel, pScope.jumpVel, forwardColour, leftColour, backColour, rightColour, duckColour, jumpColour));


    pScope.prevFlags = pScope.flags;
}

function PrintVector(v) return format("%.3f, %.3f, %.3f", v.x, v.y, v.z);

// Called after the entity is spawned
function OnPostSpawn()
{
    hPlayer = Entities.FindByName(null, "@LocalPlayer");
    hPlayer.ValidateScriptScope();
    local pScope = hPlayer.GetScriptScope();

    if (hPlayer != null) {
        pScope.buttons <- 0x0;
        pScope.flags <- 0x0;
        pScope.prevFlags <- 0x0;
        pScope.prevAngles <- Vector(0, 0, 0);
        pScope.prevStrafe <- Strafes_t.ST_NONE;
        pScope.jumpPos <- Vector(0, 0, 0);
        pScope.jumpVel <- 0.0;
        pScope.jumpAngle <- Vector(0, 0, 0);
        pScope.jumpStrafes <- 0;
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
        // hTimer.__KeyValueFromString( "classname", "soundent" );
		hTimer.ValidateScriptScope();
		local scope = hTimer.GetScriptScope();
		scope.OnTimer <- OnTimer;
		hTimer.ConnectOutput( "OnTimer", "OnTimer" );
		EntFireByHandle( hTimer, "Enable", "", 0, null, null );
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
		EntFireByHandle( pScope.eyes, "SetMeasureReference", szName, 0.0, null, null );
		EntFireByHandle( pScope.eyes, "Enable", "" , 0.0, null, null );
        EntFireByHandle( pScope.eyes, "SetMeasureTarget", "@LocalPlayer", 0.0, null, null );
        pScope.eyes.SetOwner( hPlayer );
    }
}

function SetupInputs()
{
    if (hGameUI == null)
    {
        hGameUI = CreateGameUI("@GameUI_Local", 128);

        // better than .ConnectOutput and have a million functions, all inputs proccesed through two functions & identified using buttons
        EntFireByHandle(hGameUI, "AddOutput", "PlayerOff @GameUI_Local:RunScriptCode:OnPlus(Buttons_t.IN_USE):0:-1", 0, null, null);
        EntFireByHandle(hGameUI, "AddOutput", "PressedMoveLeft @GameUI_Local:RunScriptCode:OnPlus(Buttons_t.IN_MOVELEFT):0:-1", 0, null, null);
        EntFireByHandle(hGameUI, "AddOutput", "UnpressedMoveLeft @GameUI_Local:RunScriptCode:OnMinus(Buttons_t.IN_MOVELEFT):0:-1", 0, null, null);
        EntFireByHandle(hGameUI, "AddOutput", "PressedMoveRight @GameUI_Local:RunScriptCode:OnPlus(Buttons_t.IN_MOVERIGHT):0:-1", 0, null, null);
        EntFireByHandle(hGameUI, "AddOutput", "UnpressedMoveRight @GameUI_Local:RunScriptCode:OnMinus(Buttons_t.IN_MOVERIGHT):0:-1", 0, null, null);
        EntFireByHandle(hGameUI, "AddOutput", "PressedForward @GameUI_Local:RunScriptCode:OnPlus(Buttons_t.IN_FORWARD):0:-1", 0, null, null);
        EntFireByHandle(hGameUI, "AddOutput", "UnpressedForward @GameUI_Local:RunScriptCode:OnMinus(Buttons_t.IN_FORWARD):0:-1", 0, null, null);
        EntFireByHandle(hGameUI, "AddOutput", "PressedBack @GameUI_Local:RunScriptCode:OnPlus(Buttons_t.IN_BACK):0:-1", 0, null, null);
        EntFireByHandle(hGameUI, "AddOutput", "UnpressedBack @GameUI_Local:RunScriptCode:OnMinus(Buttons_t.IN_BACK):0:-1", 0, null, null);
        EntFireByHandle(hGameUI, "AddOutput", "PressedAttack @GameUI_Local:RunScriptCode:OnPlus(Buttons_t.IN_ATTACK):0:-1", 0, null, null);
        EntFireByHandle(hGameUI, "AddOutput", "UnpressedAttack @GameUI_Local:RunScriptCode:OnMinus(Buttons_t.IN_ATTACK):0:-1", 0, null, null);
        EntFireByHandle(hGameUI, "AddOutput", "PressedAttack2 @GameUI_Local:RunScriptCode:OnPlus(Buttons_t.IN_ATTACK2):0:-1", 0, null, null);
        EntFireByHandle(hGameUI, "AddOutput", "UnpressedAttack2 @GameUI_Local:RunScriptCode:OnMinus(Buttons_t.IN_ATTACK2):0:-1", 0, null, null);

        EntFireByHandle(hGameUI, "Activate", "", 0.0, hPlayer, hPlayer);
    }

    if (hJumpUI == null)
    {
        hJumpUI = CreateGameUI("@GameUI_Jump", 256)
        EntFireByHandle(hJumpUI, "AddOutput", "PlayerOff @GameUI_Jump:RunScriptCode:OnPlus(Buttons_t.IN_JUMP):0:-1", 0, null, null);
        EntFireByHandle(hJumpUI, "Activate", "@LocalPlayer", 0.0, null, null);
    }
}

function OnPlus( input )
{
    hPlayer.ValidateScriptScope();
    local pScope = hPlayer.GetScriptScope();

    switch (input) {
        case Buttons_t.IN_USE:
            flUseReset = Time() + 0.2; // Use reset time
            EntFireByHandle(hGameUI, "Activate", "@LocalPlayer", 0.0, null, null);
        case Buttons_t.IN_JUMP:
            flJumpReset = Time() + 0.01; // Jump reset time
            EntFireByHandle(hJumpUI, "Activate", "@LocalPlayer", 0.0, null, null);
    }

    pScope.buttons = pScope.buttons | input;
}

function OnMinus( input )
{
    hPlayer.ValidateScriptScope();
    local pScope = hPlayer.GetScriptScope();
    pScope.buttons = pScope.buttons & ~input;
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
    // vVel.y = (vVel.y / 120.0) + vPos.y;

    DebugDrawLine(Vector(vPos.x, vPos.y, pScope.jumpPos.z), vVel, r, g, 0, false, 2.0);
    // DebugDrawLine(vPos, vVel, r, g, 0, false, 2.0);
}

function CreateGameUI( targetname, spawnflags )
{
    local ent = Entities.CreateByClassname("game_ui");
    ent.__KeyValueFromString("targetname", targetname);
    ent.__KeyValueFromInt("spawnflags", spawnflags);
    ent.__KeyValueFromFloat("fieldofview", -1.0)
    return ent;
}

function PrintLogo()
{

    printl(".-------------------------------------------.");
    printl("| Made by                                   |")
    printl("|                                           |")
    printl("|     '||            .'|.             '||'  |");
    printl("|   .. ||    ....  .||.   ... ...      ||   |");
    printl("| .'  '||  .|...||  ||     ||  ||      ||   |");
    printl("| |.   ||  ||       ||     ||  ||      ||   |");
    printl("| '|..'||.  '|...' .||.    '|..'|. || .|'   |");
    printl("|                                   '''     |");
    printl("'-------------------------------------------'");
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
    hPlayer.SetOrigin(pScope.telePos);
    hPlayer.SetAngles(pScope.teleAng.x, pScope.teleAng.y, pScope.teleAng.z);
}

PrintLogo();
OnPostSpawn();
