
// Handgrenades mutator
// Intended for the Camping Rifle Arena mode

void HG_Precache() {
	precache_sound("hk/alarm.wav");
	precache_sound("weapons/grenade_bounce1.wav");
	precache_sound("weapons/grenade_bounce2.wav");
	precache_sound("weapons/grenade_bounce3.wav");
	precache_sound("weapons/grenade_bounce4.wav");
	precache_sound("weapons/grenade_bounce5.wav");
	precache_sound("weapons/grenade_bounce6.wav");
	precache_sound("weapons/grenade_fire.wav");
}

void HG_GiveBonus(entity p, float hgtype, float amount, string reason) {
	p.hg_bonus += amount;
	p.hg_bonustype = hgtype;
	p.hg_ammo += amount;
	
	string n = HG_TypeToExpandedName(hgtype);
	entity e;
	
	FOR_EACH_PLAYER(e)
		bigprint_spec(e, strcat("^3", p.netname), strcat("Got a ^3", n, "^7 bonus (", reason, ")"), 3);
	bprint(strcat("^3", p.netname, " ^7got a ^3", n, "^7 bonus (", reason, ")\n"));
	play2all("kh/alarm.wav");
}

void HG_Napalm_Burn (float dt, float dist, float damage, float edgedamage, float burntime)
{
	entity e, o;
	float d, df;
	vector p;
	
	o = self.owner;
	df = 1;

	for(e = findradius(self.origin, dist); e; e = e.chain) if(e.classname == "player")
	{
		if(g_freezetag)
		if(e.freezetag_frozen)
			continue;
		
		if(o.team == e.team)
		{
			if(teamplay == 1)
				continue;
			else if(e != o)
			{
				if(teamplay == 3)
					continue;
				else if(teamplay == 4) {
					df = cvar("g_friendlyfire");
					
					if(df == 0)
						continue;
				}
			}
		}
		
		p = e.origin;
		p_x += e.mins_x + random() * (e.maxs_x - e.mins_x);
		p_y += e.mins_y + random() * (e.maxs_y - e.mins_y);
		p_z += e.mins_z + random() * (e.maxs_z - e.mins_z);
		d = vlen(self.origin - p);
		if(d < dist)
		{
			traceline(p, self.origin, MOVE_NORMAL, e);
			if(/* trace_startsolid || */ trace_fraction != 1)
				continue;
			e.fireball_impactvec = p;
			d = vlen(self.origin - e.fireball_impactvec);
			d = damage + (edgedamage - damage) * (d / dist);
			Fire_AddDamage(e, self.owner, d * burntime * df, burntime, DEATH_HG_NAPALM);
		}
	}
}

void HG_Napalm_Think ()
{
	if (time > self.pushltime)
	{
		remove (self);
		return;
	}

	HG_Napalm_Burn (0.1, cvar ("g_handgrenades_napalm_burnradius"), cvar ("g_handgrenades_napalm_burndamage"), cvar ("g_handgrenades_napalm_edgeburndamage"), cvar ("g_handgrenades_napalm_burntime"));
	if (time >= self.nextparticle)
	{
		pointparticles (particleeffectnum ("fire_big"), self.org_explosion + (self.origin - self.org_explosion) * random (), '0 0 0', 1);
		self.nextparticle = time + 0.2 + random () * 0.2;
	}

	self.nextthink = time + 0.1;
}

void HG_Napalm_Middlefire_Think() {
	if(time > self.pushltime) {
		remove (self);
		return;
	}
	
	HG_Napalm_Burn(0.1, cvar("g_handgrenades_napalm_middleburnradius"), cvar("g_handgrenades_napalm_burndamage"), cvar("g_handgrenades_napalm_edgeburndamage"), cvar("g_handgrenades_napalm_burntime"));
	self.nextthink = time + 0.1;
}

void HG_Napalm (void)
{
	local entity proj;
	local vector kick;

	proj = spawn ();
	proj.owner = self.owner;
	proj.classname = "grenade";
	proj.bot_dodge = TRUE;
	proj.bot_dodgerating = cvar ("g_handgrenades_napalm_burndamage");
	proj.movetype = MOVETYPE_BOUNCE;
	proj.projectiledeathtype = DEATH_HG_NAPALM;
	proj.touch = W_Firemine_Touch;
	PROJECTILE_MAKETRIGGER(proj);
	setsize (proj, '0 0 0', '0 0 0');
	setorigin (proj, self.origin);
	proj.org_explosion = self.origin;
	proj.think = HG_Napalm_Think;
	proj.nextthink = time;
	proj.reset = SUB_Remove;
	proj.damageforcescale = cvar ("g_handgrenades_napalm_damageforcescale");
	kick_x = (random () - 0.5) * 2 * cvar ("g_handgrenades_napalm_spread_xy");
	kick_y = (random () - 0.5) * 2 * cvar ("g_handgrenades_napalm_spread_xy");
	kick_z = max(
						cvar("g_handgrenades_napalm_spread_z")
					*	random(),
					
						cvar("g_handgrenades_napalm_spread_z_min")
					+ 	cvar("g_handgrenades_napalm_spread_z_min_randomfactor")
					*	(random() - 0.5) * 2
				);
	proj.velocity = kick;
	proj.pushltime = time + cvar ("g_handgrenades_napalm_fire_lifetime");
	W_SetupProjectileVelocity(proj);

	proj.angles = vectoangles(proj.velocity);
	proj.flags = FL_PROJECTILE;

	CSQCProjectile(proj, TRUE, PROJECTILE_FIREMINE, TRUE);
}

void HG_Napalm_Explode (void)
{
	local float c;
	for (c = 0; c < cvar ("g_handgrenades_napalm_numparticles"); c ++) HG_Napalm ();
	
	// since we have a ton of fire in the middle, let's make it a real fire
	entity mid = spawn();
	mid.owner = self.owner;
	mid.origin = self.origin;
	setorigin(mid, mid.origin);
	mid.think = HG_Napalm_Middlefire_Think;
	mid.nextthink = time;
	mid.pushltime = time + cvar ("g_handgrenades_napalm_fire_lifetime");
	setsize(mid, '0 0 0', '0 0 0');
}

string HG_TypeToExpandedName(float t) {
	switch(t) {
		case HG_NORMAL: return "Grenade";
		case HG_NAPALM: return "Napalm Grenade";
		case HG_STICKY: return "Sticky Grenade";
		default		  : return "Fuckoff Grenade";
	}
}

string HG_TypeToName(float t) {
	switch(t) {
		case HG_NORMAL: return "normal";
		case HG_NAPALM: return "napalm";
		case HG_STICKY: return "sticky";
		default		  : return "fuckoff";
	}
}

float HG_NameToType(string t) {
	switch(t) {
		case "napalm": return HG_NAPALM;
	 // case "sticky": return HG_STICKY; // Not implemented yet
		default		 : return HG_NORMAL;
	}
}

float HG_TypeToCSQCProjType(float t) {
	switch(t) {
		case HG_NAPALM:	return PROJECTILE_HG_NAPALM;
		default:		return PROJECTILE_HG_GENERIC;
	}
}

#define GV(v) (GRENVAR(self.hg_type, v))

void HG_Grenade_Explode()
{
	if(other.takedamage == DAMAGE_AIM)
		if(other.classname == "player")
			if(IsDifferentTeam(self.owner, other))
				if(IsFlying(other))
					announce(self.owner, "announcer/male/airshot.wav");

	self.event_damage = SUB_Null;
	self.takedamage = DAMAGE_NO;
	
	if(self.hg_type == HG_NAPALM)
		HG_Napalm_Explode(); // TODO move this to CSQC too
//	else HG_Normal_Explode();
	
	RadiusDamage(self, self.owner, GV("damage"), GV("edgedamage"), GV("radius"), world, GV("force"), self.projectiledeathtype, other);
	remove (self);
}
#undef GV

void HG_Touch (void)
{
	PROJECTILE_TOUCH;
	if (other.takedamage == DAMAGE_AIM)
	{
		self.use ();
	}
	else
	{
		float r;
		r = random() * 6;
		if(r < 1)
			spamsound (self, CHAN_PROJECTILE, "weapons/grenade_bounce1.wav", VOL_BASE, ATTN_NORM);
		else if(r < 2)
			spamsound (self, CHAN_PROJECTILE, "weapons/grenade_bounce2.wav", VOL_BASE, ATTN_NORM);
		else if(r < 3)
			spamsound (self, CHAN_PROJECTILE, "weapons/grenade_bounce3.wav", VOL_BASE, ATTN_NORM);
		else if(r < 4)
			spamsound (self, CHAN_PROJECTILE, "weapons/grenade_bounce4.wav", VOL_BASE, ATTN_NORM);
		else if(r < 5)
			spamsound (self, CHAN_PROJECTILE, "weapons/grenade_bounce5.wav", VOL_BASE, ATTN_NORM);
		else
			spamsound (self, CHAN_PROJECTILE, "weapons/grenade_bounce6.wav", VOL_BASE, ATTN_NORM);
	}
}

void HG_Attack()
{
	#define GV(v) (GRENVAR(hgtype, v))
	float hgtype;
	
	if(time < self.hg_next || !self.hg_ammo)
		return;
	
	self.hg_type = HG_NameToType(cvar_string("g_handgrenades_type"));
	
	if(self.hg_bonus) {
		hgtype = self.hg_bonustype;
		self.hg_bonus -= 1;
	} else
		hgtype = self.hg_type;
	
	vector hitmins, hitmaxs;

	if(cvar("g_handgrenades_oldhitboxes")) {
		hitmins = '0 0 -3';
		hitmaxs = '0 0 -3';
	} else {
		hitmins = '-8 -4 -3';
		hitmaxs = ' 8  4  3';
	}
	makevectors(self.v_angle);
	W_SetupShot_ProjectileSize (self, hitmins, hitmaxs, FALSE, 4, "weapons/grenade_fire.wav", GV("damage"));
	w_shotdir = v_forward;
	
	pointparticles(particleeffectnum("grenadelauncher_muzzleflash"), w_shotorg, w_shotdir * 1000, 1);
	
	entity gren = spawn ();
	gren.owner = self;
	gren.classname = "go_to_bed_samual";
	gren.bot_dodge = TRUE;
	gren.bot_dodgerating = GV("damage");
	gren.movetype = MOVETYPE_BOUNCE;
	PROJECTILE_MAKETRIGGER(gren);
	gren.projectiledeathtype = hgtype;
	gren.hg_type = hgtype;
	setsize(gren, hitmins, hitmaxs);
	setorigin(gren, w_shotorg);

	gren.nextthink = ((self.hg_power == 1)? time + 0.01 : time + GV("lifetime"));
	gren.think = adaptor_think2use;
	gren.use = HG_Grenade_Explode;
	gren.touch = HG_Touch;
	gren.takedamage = DAMAGE_YES;
	gren.health = GV("health");
	gren.damageforcescale = GV("damageforcescale");
	gren.event_damage = W_Grenade_Damage;
	gren.velocity = w_shotdir * GV("speed") * self.hg_power + v_up * GV("speed_up") * self.hg_power;
	W_SetupProjectileVelocity(gren);
	
	gren.angles = vectoangles (gren.velocity);
	gren.flags = FL_PROJECTILE;
	
	CSQCProjectile(gren, TRUE, HG_TypeToCSQCProjType(hgtype), TRUE);
	
	if (hgtype == HG_NAPALM && self.hg_power == 1)
		Damage(self, self, self, GV("kamikaze_damage"), DEATH_SHOOTING_STAR, self.origin, '0 0 0');
		
	self.hg_next = time + cvar("g_handgrenades_mindelay");
	self.hg_ammo -= 1;
	
	#undef GV
}

void HG_Frame()
{
	if(!g_handgrenades || time < game_starttime)
		return;
	
	float mayfire = (!g_grappling_hook || (!self.hook && !CustomCRAHookButton(self))) || self.hg_power;
	
	float held;
	held = self.BUTTON_HG;
	
	if((self.hg_power && !self.hg_state		)||
	   (g_freezetag && self.freezetag_frozen))
			held = 0;
	
	if(held && held != self.hg_state && !self.hg_ammo && self.deadflag == DEAD_NO && !g_grappling_hook)
		bigprint_spec(self, "Out of Grenades", "", 1);
	
	if(held && time >= self.hg_next && self.hg_ammo && mayfire)
		self.hg_power = bound(0,
			self.hg_power + frametime *
			cvar("g_handgrenades_speed"),
		1);
	else
	{
		self.hg_power = bound(0,
			self.hg_power - frametime *
			cvar("g_handgrenades_clearspeed"),
		1);
		
		if(self.hg_state && mayfire)
			HG_Attack();
	}
	
	if(self.hg_power == 1 && mayfire)
		HG_Attack(); 	// inhand explosion
	
	self.hg_state = held;
}

void HG_PlayerSpawn()
{
	self.hg_power = 0;
	self.hg_ammo = cvar("g_handgrenades_ammo");
	self.hg_bonus = 0;
	self.hg_bonustype = HG_NORMAL;
}
