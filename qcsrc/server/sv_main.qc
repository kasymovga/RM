
void CreatureFrame (void)
{
	local entity oldself;
	local float dm;
	oldself = self;
	self = findfloat(world, iscreature, TRUE);
	while (self)
	{
		if (self.movetype != MOVETYPE_NOCLIP)
		{
			if (self.waterlevel)
			{
				if (!(self.flags & FL_INWATER))
				{
					self.flags |= FL_INWATER;
					self.dmgtime = 0;
				}
				if (self.waterlevel != WATERLEVEL_SUBMERGED)
				{
					if(self.air_finished < time + 9)
						PlayerSound(playersound_gasp, CHAN_PLAYER, VOICETYPE_PLAYERSOUND);
					self.air_finished = time + 12;
					self.dmg = 2;
				}
				else if (self.air_finished < time)
				{	// drown!
					if (!self.deadflag)
					if (self.pain_finished < time)
					{
						Damage (self, world, world, 5, DEATH_DROWN, self.origin, '0 0 0');
						self.pain_finished = time + 0.5;
					}
				}
				if (self.dmgtime < time)
				{
					self.dmgtime = time + 0.1;
					if (self.watertype == CONTENT_LAVA)
					{
						if (self.watersound_finished < time)
						{
							self.watersound_finished = time + 0.5;
							sound (self, CHAN_PLAYER, "player/lava.wav", VOL_BASE, ATTN_NORM);
						}
						Damage (self, world, world, 6 * self.waterlevel, DEATH_LAVA, self.origin, '0 0 0');
					}
					else if (self.watertype == CONTENT_SLIME)
					{
						if (self.watersound_finished < time)
						{
							self.watersound_finished = time + 0.5;
							sound (self, CHAN_PLAYER, "player/slime.wav", VOL_BASE, ATTN_NORM);
						}
						Damage (self, world, world, 2 * self.waterlevel, DEATH_SLIME, self.origin, '0 0 0');
					}
				}
			}
			else
			{
				if (self.flags & FL_INWATER)
				{
					// play leave water sound
					self.flags &~= FL_INWATER;
					self.dmgtime = 0;
				}
				self.air_finished = time + 12;
				self.dmg = 2;
			}
			// check for falling damage
			if(!self.hook.state)
			{
				dm = vlen(self.oldvelocity) - vlen(self.velocity); // dm is now the velocity DECREASE. Velocity INCREASE should never cause a sound or any damage.
				if (self.deadflag)
					dm = (dm - cvar("g_balance_falldamage_deadminspeed")) * cvar("g_balance_falldamage_factor");
				else
					dm = min((dm - cvar("g_balance_falldamage_minspeed")) * cvar("g_balance_falldamage_factor"), cvar("g_balance_falldamage_maxdamage"));
				if (dm > 0)
				{
					Damage (self, world, world, dm, DEATH_FALL, self.origin, '0 0 0');
				}
				else if(vlen(self.velocity) > 100000 && cvar("developer"))
				{
					dprint(strcat(self.netname, " became too fast, please investigate: ", vtos(self.spawnorigin), "\n"));
					Damage (self, world, world, 50000, DEATH_SHOOTING_STAR, self.origin, '0 0 0');
				}
			}

			// play stupid sounds
			if (g_footsteps)
			if (!gameover)
			if (self.flags & FL_ONGROUND)
			if (vlen(self.velocity) > sv_maxspeed * 0.6)
			if (!self.deadflag)
			if (time < self.lastground + 0.2)
			{
				if((time > self.nextstep) || (time < (self.nextstep - 10.0)))
				{
					self.nextstep = time + 0.3 + random() * 0.1;
					trace_dphitq3surfaceflags = 0;
					tracebox(self.origin, self.mins, self.maxs, self.origin - '0 0 1', MOVE_NOMONSTERS, self);
					/*
					if(trace_fraction == 1)
						dprint("nohit\n");
					else
						dprint(ftos(trace_dphitq3surfaceflags), "\n");
					*/
					if not(trace_dphitq3surfaceflags & Q3SURFACEFLAG_NOSTEPS)
					{
						if(trace_dphitq3surfaceflags & Q3SURFACEFLAG_METALSTEPS)
							GlobalSound(globalsound_metalstep, CHAN_PLAYER, VOICETYPE_PLAYERSOUND);
						else
							GlobalSound(globalsound_step, CHAN_PLAYER, VOICETYPE_PLAYERSOUND);
					}
				}
			}
			self.oldvelocity = self.velocity;
		}
		self = findfloat(self, iscreature, TRUE);
	}
	self = oldself;
}

// This returns the player who's been afk for the longest amount of time
entity GetAFKKickVictim() {
	entity v, e;
	
	FOR_EACH_REALCLIENT(e) if(e.is_away)
		if(!v || v.parm_idlesince > e.parm_idlesince)
			v = e;
	
	return v;
}

/*
=============
StartFrame

Called before each frame by the server
=============
*/
void RuneMatchGivePoints();
float RedirectionThink();

string oldfog;

entity SelectSpawnPoint (float anypoint);
void StartFrame (void)
{
	remove = remove_unsafely; // not during spawning!
	serverprevtime = servertime;
	servertime = time;
	serverframetime = frametime;

#ifdef PROFILING
	if(time > client_cefc_accumulatortime + 1)
	{
		float t, pp, c_seeing, c_seen;
		entity cl;
		t = client_cefc_accumulator / (time - client_cefc_accumulatortime);
		print("CEFC time: ", ftos(t * 1000), "ms; ");
		c_seeing = 0;
		c_seen = 0;
		FOR_EACH_CLIENT(cl)
		{
			if(clienttype(cl) == CLIENTTYPE_REAL)
				++c_seeing;
			if(cl.classname == "player")
				++c_seen;
		}
		print("CEFC calls per second: ", ftos(c_seeing * (c_seen - 1) / t), "; ");
		print("CEFC 100% load at: ", ftos(solve_quadratic(t, -t, -1) * '0 1 0'), "\n");

		client_cefc_accumulatortime = time;
		client_cefc_accumulator = 0;
	}
#endif

	dprint_load(); // load dprint status from cvar

	entity e;
	for(e = world; (e = findfloat(e, csqcprojectile_clientanimate, 1)); )
		CSQCProjectile_Check(e);

	if(RedirectionThink())
		return;

	UncustomizeEntitiesRun();
	InitializeEntitiesRun();

	sv_gravity = cvar("sv_gravity");
	sv_maxairspeed = cvar("sv_maxairspeed");
	sv_maxspeed = cvar ("sv_maxspeed");
	sv_friction = cvar ("sv_friction");
	sv_accelerate = cvar ("sv_accelerate");
	sv_airaccelerate = cvar("sv_airaccelerate");
	sv_airaccel_sideways_friction = cvar("sv_airaccel_sideways_friction");
	sv_airaccel_qw = cvar("sv_airaccel_qw");
	sv_stopspeed = cvar ("sv_stopspeed");
	sv_airstopaccelerate = cvar("sv_airstopaccelerate");
	sv_airstrafeaccelerate = cvar("sv_airstrafeaccelerate");
	sv_maxairstrafespeed = cvar("sv_maxairstrafespeed");
	sv_aircontrol = cvar("sv_aircontrol");
	sv_warsowbunny_airforwardaccel = cvar("sv_warsowbunny_airforwardaccel");
	sv_warsowbunny_accel = cvar("sv_warsowbunny_accel");
	sv_warsowbunny_topspeed = cvar("sv_warsowbunny_topspeed");
	sv_warsowbunny_turnaccel = cvar("sv_warsowbunny_turnaccel");
	sv_warsowbunny_backtosideratio = cvar("sv_warsowbunny_backtosideratio");
	teamplay = cvar ("teamplay");
	sys_ticrate = cvar("sys_ticrate");

	if (timeoutStatus == 1) // just before the timeout (when timeoutStatus will be 2)
		orig_slowmo = cvar("slowmo"); // slowmo will be restored after the timeout

	if(teams_matter && !teamplay)
		teamplay = 3;
	if(!teams_matter && teamplay)
		teamplay = 0;

	skill = cvar("skill");

	Spawnqueue_Check();

	// if in warmup stage and limit for warmup is hit start match
	if (!forbidrestart)
	if (inWarmupStage)
	// But not during the god damn intermission you dump piece of shit
	if (!intermission_running)
	if ((g_warmup_limit > 0 && time >= g_warmup_limit)
	 || (g_warmup_limit == 0 && cvar("timelimit") != 0 && time >= cvar("timelimit") * 60))
	{
		ReadyRestart();
		return;
	}

	CreatureFrame ();
	CheckRules_World ();

	AuditTeams();

	RuneMatchGivePoints();
	bot_serverframe();

	if(cvar("spawn_debugview"))
	{
		RandomSelection_Init();
		for(self = world; (self = find(self, classname, "player")); )
			RandomSelection_Add(self, 0, string_null, 1, 0);
		self = RandomSelection_chosen_ent;
		SelectSpawnPoint(0);
	}

	FOR_EACH_PLAYER(self)
		self.porto_forbidden = max(0, self.porto_forbidden - 1);
	
	if(ShouldForceFog()) {
		string newfog = GetForcedFog();
		
		if(newfog != oldfog) {
			print("Fog settings updated\n");
			
			if(oldfog)
				strunzone(oldfog);
			oldfog = strzone(newfog);
			
			FOR_EACH_REALCLIENT(self)
				stuffcmd(self, strcat("prvm_globalset client forcefog \"", newfog, "\"\n"));
		}
	} else if(oldfog) {
		print("Fog disabled\n");
		strunzone(oldfog);
		oldfog = string_null;
		
		FOR_EACH_REALCLIENT(self) {
			stuffcmd(self, "prvm_globalset client forcefog \"\"\n");
			stuffcmd(self, "defer 0 \"fog 0\"\n");
		}
	}
	
	if(totalclients >= maxclients) if(cvar("sv_autoaway_kick")) {
		entity v = GetAFKKickVictim();
		
		if(v) {
			bprint("^3", v.netname, " ^7has been kicked for being AFK for ", ftos(floor((time - v.parm_idlesince) / 60)), " minutes while the server is full\n");
			dropclient(v);
		}
	}
}

string gametype_patterns() {
	string s = cvar_string("sv_gametype_patterns");
	if (s == "") //Trying to guess
	{
		if (teams_matter)
		{
			s = "team|ctf";
		}
		else if(cvar("g_maxplayers") == 2)
		{
			s = "tournament|duel";
		}
		else
		{
			s = "ffa";
		}
	}
	return s;
}

.vector originjitter;
.vector anglesjitter;
.float anglejitter;
.string gametypefilter;
.string gametype;
.string not_gametype;
.string cvarfilter;
void SV_OnEntityPreSpawnFunction()
{
	if not(self) //no needed for worldspawn
		return;

	if(self.gametypefilter != "")
	if not(isGametypeInFilter(game, teams_matter, self.gametypefilter))
	{
		remove(self);
		return;
	}
	string s;
	float n, i;
	if (self.gametype != "")
	{
		s = gametype_patterns();
		float matched;
		matched = 0;
		n = tokenizebyseparator(s, "|");
		for (i = 0; i < n; i++)
		{
			s = argv(i);
			if(s == "")
				continue;
			if(strstrofs(self.gametype, s, 0) >= 0)
			{
				print(strcat("Found pattern '", s, "' for entity '", self.classname, "' with gametype '", self.gametype, "'\n"));
				matched = 1;
				break;
			}
		}
		if not(matched)
		{
			print(strcat("Removed entity '", self.classname, "' with gametype '", self.gametype, "' because no patterns found\n"));
			remove(self);
			return;
		}
	}
	if (self.not_gametype != "")
	{
		s = gametype_patterns();
		n = tokenizebyseparator(s, "|");
		for (i = 0; i < n; i++)
		{
			s = argv(i);
			if(s == "")
				continue;
			if(strstrofs(self.not_gametype, s, 0) >= 0)
			{
				print(strcat("Removed entity '", self.classname, "' with not allowed gametype '", self.not_gametype, "' because patterns found\n"));
				remove(self);
				return;
			}
		}
	}
	if(self.cvarfilter != "")
	{
		float o, inv;
		string k, v;
		inv = 0;

		s = self.cvarfilter;
		if(substring(s, 0, 1) == "+")
		{
			s = substring(s, 1, -1);
		}
		else if(substring(s, 0, 1) == "-")
		{
			inv = 1;
			s = substring(s, 1, -1);
		}

		n = tokenize(s);
		for(i = 0; i < n; ++i)
		{
			s = argv(i);
			// syntax:
			// var>x
			// var<x
			// var>=x
			// var<=x
			// var==x
			// var!=x
			// var===x
			// var!==x
			if((o = strstrofs(s, ">=", 0)) >= 0)
			{
				k = substring(s, 0, o);
				v = substring(s, o+2, -1);
				if(cvar(k) < stof(v))
					goto cvar_fail;
			}
			else if((o = strstrofs(s, "<=", 0)) >= 0)
			{
				k = substring(s, 0, o);
				v = substring(s, o+2, -1);
				if(cvar(k) > stof(v))
					goto cvar_fail;
			}
			else if((o = strstrofs(s, ">", 0)) >= 0)
			{
				k = substring(s, 0, o);
				v = substring(s, o+1, -1);
				if(cvar(k) <= stof(v))
					goto cvar_fail;
			}
			else if((o = strstrofs(s, "<", 0)) >= 0)
			{
				k = substring(s, 0, o);
				v = substring(s, o+1, -1);
				if(cvar(k) >= stof(v))
					goto cvar_fail;
			}
			else if((o = strstrofs(s, "==", 0)) >= 0)
			{
				k = substring(s, 0, o);
				v = substring(s, o+2, -1);
				if(cvar(k) != stof(v))
					goto cvar_fail;
			}
			else if((o = strstrofs(s, "!=", 0)) >= 0)
			{
				k = substring(s, 0, o);
				v = substring(s, o+2, -1);
				if(cvar(k) == stof(v))
					goto cvar_fail;
			}
			else if((o = strstrofs(s, "===", 0)) >= 0)
			{
				k = substring(s, 0, o);
				v = substring(s, o+2, -1);
				if(cvar_string(k) != v)
					goto cvar_fail;
			}
			else if((o = strstrofs(s, "!==", 0)) >= 0)
			{
				k = substring(s, 0, o);
				v = substring(s, o+2, -1);
				if(cvar_string(k) == v)
					goto cvar_fail;
			}
			else if(substring(s, 0, 1) == "!")
			{
				k = substring(s, 1, -1);
				if(cvar(k))
					goto cvar_fail;
			}
			else
			{
				k = s;
				if not(cvar(k))
					goto cvar_fail;
			}
		}
		inv = !inv;
:cvar_fail
		// now inv is 1 if we want to keep the item, and 0 if we want to get rid of it
		if not(inv)
		{
			//print("cvarfilter fail\n");
			remove(self);
			return;
		}
	}

	// support special -1 and -2 angle from radiant
	if (self.angles == '0 -1 0')
		self.angles = '-90 0 0';
	else if (self.angles == '0 -2 0')
		self.angles = '+90 0 0';

	if(self.originjitter_x != 0)
		self.origin_x = self.origin_x + (random() * 2 - 1) * self.originjitter_x;
	if(self.originjitter_y != 0)
		self.origin_y = self.origin_y + (random() * 2 - 1) * self.originjitter_y;
	if(self.originjitter_z != 0)
		self.origin_z = self.origin_z + (random() * 2 - 1) * self.originjitter_z;
	if(self.anglesjitter_x != 0)
		self.angles_x = self.angles_x + (random() * 2 - 1) * self.anglesjitter_x;
	if(self.anglesjitter_y != 0)
		self.angles_y = self.angles_y + (random() * 2 - 1) * self.anglesjitter_y;
	if(self.anglesjitter_z != 0)
		self.angles_z = self.angles_z + (random() * 2 - 1) * self.anglesjitter_z;
	if(self.anglejitter != 0)
		self.angles_y = self.angles_y + (random() * 2 - 1) * self.anglejitter;
    
    string repl = cvar_string(strcat("sv_spawnreplace_", self.classname));

    if(repl != "") {
        // XXX: this is never strunzoned because darkplaces is stupid and doesn't support a SV_OnEntityPreRemove()
        self.classname = strzone(repl);
    }
}
