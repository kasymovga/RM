
void() havocbot_role_ft_freeing;
void() havocbot_role_ft_offense;

void havocbot_goalrating_freeplayers(float ratingscale, vector org, float sradius)
{
	entity head;
	float distance;

	FOR_EACH_PLAYER(head)
	{
		if ((head != self) && (head.team == self.team))
		{
			if (head.freezetag_frozen)
			{
				distance = vlen(head.origin - org);
				if (distance > sradius)
					continue;
					navigation_routerating(head, ratingscale, 2000); //xonotic
			}
			else
			{
				// If teamate is not frozen still seek them out as fight better
				// in a group.
				navigation_routerating(head, ratingscale/4, 2000); //xonotic - /3, my was /8
			}
		}
	}
}

void havocbot_role_ft_offense()
{
	entity head;
	float unfrozen;

	if(self.deadflag != DEAD_NO)
		return;

	if (!self.havocbot_role_timeout)
		self.havocbot_role_timeout = time + random() * 10 + 20;

	// Count how many players on team are unfrozen.
	unfrozen = 0;
	FOR_EACH_PLAYER(head)
	{
		if ((head.team == self.team) && (!head.freezetag_frozen))
			unfrozen++;
	}

	// If only one left on team or if role has timed out then start trying to free players.
	if (((unfrozen == 0) && (!self.freezetag_frozen)) || (time > self.havocbot_role_timeout))
	{
		dprint("changing role to freeing\n");
		self.havocbot_role = havocbot_role_ft_freeing;
		self.havocbot_role_timeout = 0;
		return;
	}

	if (time > self.bot_strategytime)
	{
		//self.bot_strategytime = time + autocvar_bot_ai_strategyinterval;
		self.bot_strategytime = time + cvar("bot_ai_strategyinterval");
		
		navigation_goalrating_start();
		havocbot_goalrating_items(10000, self.origin, 10000);
		havocbot_goalrating_enemyplayers(20000, self.origin, 10000);
		havocbot_goalrating_freeplayers(9000, self.origin, 10000); //xonotic
//		havocbot_goalrating_freeplayers(35000, self.origin, 10000); //my test
		//havocbot_goalrating_waypoints(1, self.origin, 1000);
		navigation_goalrating_end();
	}
}

void havocbot_role_ft_freeing()
{
	if(self.deadflag != DEAD_NO)
		return;

	if (!self.havocbot_role_timeout)
		self.havocbot_role_timeout = time + random() * 10 + 20;

	if (time > self.havocbot_role_timeout)
	{
		dprint("changing role to offense\n");
		self.havocbot_role = havocbot_role_ft_offense;
		self.havocbot_role_timeout = 0;
		return;
	}

	if (time > self.bot_strategytime)
	{
		//self.bot_strategytime = time + autocvar_bot_ai_strategyinterval;
		self.bot_strategytime = time + cvar("bot_ai_strategyinterval");

		navigation_goalrating_start();
		havocbot_goalrating_items(8000, self.origin, 10000);
		havocbot_goalrating_enemyplayers(10000, self.origin, 10000); //xonotic
		havocbot_goalrating_freeplayers(20000, self.origin, 10000); //xonotic
//		havocbot_goalrating_enemyplayers(9000, self.origin, 10000); //my test
// 		havocbot_goalrating_freeplayers(30000, self.origin, 10000); //my test
		//havocbot_goalrating_waypoints(1, self.origin, 1000);
		navigation_goalrating_end();
	}
}

void havocbot_chooserole_ft()
{
	self.havocbot_role = havocbot_role_ft_offense;
};