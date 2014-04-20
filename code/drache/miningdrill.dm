/proc/dirToX(dir)
	switch(dir)
		if(NORTH)
			return 0
		if(SOUTH)
			return 0
		if(EAST)
			return 1
		if(WEST)
			return -1

/proc/dirToY(dir)
	switch(dir)
		if(NORTH)
			return 1
		if(SOUTH)
			return -1
		if(EAST)
			return 0
		if(WEST)
			return 0


/************************ MINING DRILL ************************/


/proc/getMaterialsByLayer(var/layer)
	switch(layer)
		if(1 to 16)
			return list(/obj/item/weapon/ore/plasma, /obj/item/weapon/ore/glass)
		if(17 to 37)
			return list(/obj/item/weapon/ore/plasma, /obj/item/weapon/ore/glass, /obj/item/weapon/ore/iron)
		if(38 to 48)
			return list(/obj/item/weapon/ore/plasma, /obj/item/weapon/ore/glass, /obj/item/weapon/ore/iron, /obj/item/weapon/ore/silver)
		if(49 to 55)
			return list(/obj/item/weapon/ore/plasma, /obj/item/weapon/ore/glass, /obj/item/weapon/ore/iron, /obj/item/weapon/ore/silver, /obj/item/weapon/ore/gold, /obj/item/weapon/ore/uranium)
		if(66 to INFINITY)
			return list(/obj/item/weapon/ore/plasma, /obj/item/weapon/ore/glass, /obj/item/weapon/ore/iron, /obj/item/weapon/ore/silver, /obj/item/weapon/ore/gold, /obj/item/weapon/ore/diamond, /obj/item/weapon/ore/uranium)

var/turf/minedTurfs[0] //array of turfs already mined on and their corresponding layer.
var/turf/maxTurfLayer[0]

/mob/verb/getLayers()
	set name = "Get Layers"
	set category = "Special Commands"

	for(var/t in minedTurfs)
		usr << "[t] = [minedTurfs[t]]"
	usr << "-----------"
	for(var/tt in maxTurfLayer)
		usr << "[tt] = [maxTurfLayer[tt]]"

/obj/machinery/miningdrill
	name = "mining drill"
	desc = "A powerfull drill used for mining operations."
	icon_state = "mining_drill"

	active_power_usage = 1000
	use_power = 2
	idle_power_usage = 300
	power_channel = EQUIP
	density = 1
	anchored = 1

	var/running = 0
	var/currentLayer = 1
	var/lastOperation = 0
	var/timeMultiplier = 25
	var/timeAdder = 25
	var/maxLayer = -1

	proc/getMineTime()
		return timeAdder + currentLayer * timeMultiplier

	proc/getLayer(turf/T)
		if(!T)	return
		if(T in minedTurfs)
			currentLayer = minedTurfs[T]
		else
			minedTurfs += T
			minedTurfs[T] = 1
			currentLayer = 1

		if(T in maxTurfLayer)
			maxLayer = maxTurfLayer[T]
		else
			maxTurfLayer += T
			maxTurfLayer[T] = rand(10, 300)
			maxLayer = maxTurfLayer[T]

	proc/mine()
		if(!anchored || !running || stat == 2)	return

		var/turf/miningTurf = get_turf(src)
		if(!istype(miningTurf, /turf/simulated/floor/plating/asteroid))
			src.visible_message("<div class='warning'>The [src] fails to mine through [get_turf(src)].")
			return

		getLayer(miningTurf)

		lastOperation = world.time

		var/material = text2path("[pick(getMaterialsByLayer(currentLayer))]") // Get available materials by layer and pick a random one from the list returned.
		var/amount = rand(1, max(round(currentLayer * 0.05), 1)) // Little bit of bonus when you get deeper. Chance of one extra every 20 layers.
		var/failchance = prob(min((currentLayer * 0.04) + rand(1, 10), 75))

		if(!anchored || !running)
			return

		if(failchance || currentLayer >= maxLayer) // no ore at current layer OR  max layer.
			src.visible_message("<div class='alert'>Failed to find any ore.</div>")
			return
		else
			for(amount, amount > 0, amount--)
				new material(locate(src.x + 1, src.y, src.z)) //make sure nothing is spawning outside the map
			currentLayer++
			src.visible_message("<div class='notice'>Layer [currentLayer - 1] mined.</div>")
		minedTurfs[miningTurf] = currentLayer

	power_change()
		..()
		update_icon()

	process()
		..()
		if(anchored && running && stat != 2)
			if(world.time > lastOperation + getMineTime())
				mine()

	proc/flickIcon(var/pre = 1) //for the preparing and stopping animation.
		if(pre)
			flick("mining_drill_preparing", src)
		else
			flick("mining_drill_postparing", src)

	update_icon(flick = 1)
		if(flick)
			flickIcon(running)

		overlays.Cut()

		var/image/top_static = image('icons/obj/stationobjs.dmi', "mining_drill_top")
		top_static.pixel_y += 32
		top_static.layer = 5

		var/image/top_running = image('icons/obj/stationobjs.dmi', "mining_drill_top_running")
		top_running.pixel_y += 32
		top_running.layer = 5

		var/image/top_offline = image('icons/obj/stationobjs.dmi', "mining_drill_top0")
		top_offline.pixel_y += 32
		top_offline.layer = 5

		if(running)
			if(stat == 2)
				overlays += top_offline
				icon_state = "mining_drill_running0"
			else
				overlays += top_running
				icon_state = "mining_drill_running"
		else
			icon_state = "mining_drill"
			if(stat == 2)
				overlays += top_offline
			else
				overlays += top_static

	attack_hand(mob/M)
		..()
		if(anchored)
			if(!istype(get_turf(src), /turf/simulated/floor/plating/asteroid))
				src.visible_message("<div class='warning'>The [src] can't mine through the [get_turf(src)].")
				return
			running = !running
			update_icon()
			M << "<div class='notice'>You turn the [src] [running ? "on" : "off"].</div>"
		else
			M << "<div class='alert'>You can't turn the [src] [running ? "off" : "on"] without anchoring it first.</div>"

	attackby(obj/item/I, mob/M)
		if(istype(I,  /obj/item/weapon/wrench) && !running)
			anchored = !anchored
			M << "<div class='notice'>You [anchored ? "anchor" : "unfasten"] the [src].</div>"

	New()
		..()
		update_icon(0)
		lastOperation = world.time

	examine()
		..()
		usr << "<div class='notice'>The [src] reports:</div>"
		usr << "<div class='notice'>*Current Layer: [currentLayer].</div>"
		usr << "<div class='notice'>*Required time: [getMineTime()/10] sec.</div>"
