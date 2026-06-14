package game.states;

import game.states.betterOptions.OptionsSubState;
import haxe.extern.EitherType;
import game.backend.data.jsons.WeekData;
import game.backend.data.EngineData;
import game.objects.FlxStaticText;

import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.system.FlxAssets;

class MainMenuState extends MusicBeatState {
	static var curSelected:Int = 0;
	static final optionShit:Array<Array<EitherType<String, Void -> Class<MusicBeatState>>>> = [
		['story_mode',  () -> return game.states.StoryMenuState],
		['freeplay',    () -> return game.states.FreeplayState],
		[
			'options',
			() ->
			{
				FlxG.state.openSubState(new OptionsSubState());
				return null;
			}
		],
		['credits',     () -> return null],
	];
	var magenta:FlxSprite;
	var menuItems:FlxTypedGroup<FlxSprite>;
	var lastMouseX:Float = 0;
	var lastMouseY:Float = 0;

	override function create()
	{
		Main.canClearMem = true;
		persistentUpdate = persistentDraw = true;
		FlxG.mouse.visible = true;

		final yScroll:Float = Math.max(0.2 - (0.05 * (optionShit.length - 4)), 0.1);
		final bg:FlxSprite = new FlxSprite(Paths.image('menuBG'));
		bg.scrollFactor.set(0, yScroll);
		bg.scale.scale(1.175);
		bg.updateHitbox();
		bg.screenCenter();
		bg.active = false;
		add(bg);

		magenta = new FlxSprite(Paths.image('menuDesat'));
		magenta.scrollFactor.set(0, yScroll);
		magenta.scale.scale(1.175);
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFFD719B;
		magenta.active = false;
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		final scr:Float = optionShit.length < 6 ? 0 : (optionShit.length - 4) * 0.135;
		final offset:Float = 108 - (Math.max(optionShit.length, 4) - 4) * 80;
		for (i => data in optionShit)
		{
			final menuItem:FlxSprite = new FlxSprite(0, (i * 140) + offset);
			final nameButton:String = data[0];
			menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_' + nameButton);
			menuItem.animation.addByPrefix('idle', nameButton + " basic", 24);
			menuItem.animation.addByPrefix('selected', nameButton + " white", 24);
			menuItem.animation.play('idle');
			menuItem.centerOffsets();
			menuItem.scrollFactor.set(0, scr);
			menuItem.ID = i;
			menuItem.screenCenter(X);
			menuItems.add(menuItem);
			add(menuItem);
		}

		FlxG.camera.follow(menuItems.members[0], null, 0);
		final versionTxt:FlxStaticText = new FlxStaticText(12, FlxG.height - 8, 0, 'Twist Engine ${EngineData.engineVersion}
		Friday Night Funkin v${lime.app.Application.current.meta.get('version')}', 16);
		versionTxt.scrollFactor.set();
		versionTxt.fieldHeight = -10;
		versionTxt.borderStyle = FlxTextBorderStyle.OUTLINE;
		versionTxt.borderColor = FlxColor.BLACK;
		versionTxt.font = Paths.font('defaultPsych/vcr.ttf');
		add(versionTxt);
		versionTxt.y -= versionTxt.height;

		changeItem();

		lastMouseX = FlxG.mouse.screenX;
		lastMouseY = FlxG.mouse.screenY;

		super.create();
		#if DISCORD_RPC
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Main Menu", null);
		#end
		// WeekData.reloadWeeksFiles();
		if (FlxG.sound.music == null || !FlxG.sound.music.active)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
		Paths.clearUnusedMemory();
		Paths.clearStoredMemory();
		FlxG.camera.followLerp = 1 / 6;
	}

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		if (subState == null && !selectedSomethin)
		{
			for (i => item in menuItems.members)
			{
				var targetScale:Float = (i == curSelected) ? 1.05 : 1.0;
				var lerpVal:Float = FlxMath.bound(elapsed * 9, 0, 1);

				item.scale.set(
					FlxMath.lerp(item.scale.x, targetScale, lerpVal),
					FlxMath.lerp(item.scale.y, targetScale, lerpVal)
				);
				item.origin.set(item.frameWidth * 0.5, item.frameHeight * 0.5);
			}

			var mouseMoved:Bool = (FlxG.mouse.screenX != lastMouseX || FlxG.mouse.screenY != lastMouseY);

			if (mouseMoved)
			{
				for (i => item in menuItems.members)
				{
					if (FlxG.mouse.overlaps(item))
					{
						if (curSelected != i)
						{
							curSelected = i;
							changeItem(0, true);
						}
					}
				}
				lastMouseX = FlxG.mouse.screenX;
				lastMouseY = FlxG.mouse.screenY;
			}

			if (FlxG.mouse.wheel == 0)
			{
				if (controls.UI_UP_P)
				{
					changeItem(-1);
					lastMouseX = FlxG.mouse.screenX;
					lastMouseY = FlxG.mouse.screenY;
				}
				if (controls.UI_DOWN_P)
				{
					changeItem(1);
					lastMouseX = FlxG.mouse.screenX;
					lastMouseY = FlxG.mouse.screenY;
				}
			}
			else
			{
				changeItem(-FlxMath.signOf(FlxG.mouse.wheel));
				lastMouseX = FlxG.mouse.screenX;
				lastMouseY = FlxG.mouse.screenY;
			}

			// if (controls.BACK)
			// {
			// 	selectedSomethin = true;
			// 	FlxG.sound.play(Paths.sound('cancelMenu'));
			// 	MusicBeatState.switchState(new TitleState());
			// }

			if (controls.ACCEPT || (FlxG.mouse.justPressed && FlxG.mouse.overlaps(menuItems.members[curSelected])))
			{
				final toStateFunc:Void -> Class<MusicBeatState> = optionShit[curSelected][1];
				final toState:Class<MusicBeatState> = toStateFunc();
				if (toState != null)
				{
					FlxG.sound.play(Paths.sound('confirmMenu'));
					selectedSomethin = true;
					FlxG.mouse.visible = false;

					if (ClientPrefs.data.flashing)
						FlxFlicker.flicker(magenta, 1.1, 0.15, false);

					FlxFlicker.flicker(menuItems.members[curSelected], 1, 0.06, false, false, _ -> MusicBeatState.switchState(Type.createInstance(toState, []))
					);
					for (i in 0...menuItems.members.length)
					{
						if (i == curSelected) continue;
						FlxTween.tween(menuItems.members[i], {alpha: 0}, 0.4, {ease: FlxEase.quadOut, onComplete: function(_) menuItems.members[i].kill()});
					}
				}
			}
			#if (EDITORS_ALLOWED && desktop)
			if (controls.DEBUG_1)
			{
				selectedSomethin = true;
				MusicBeatState.switchState(new game.states.editors.MasterEditorMenu());
			}
			#end
		}

		super.update(elapsed);
	}

	function changeItem(huh:Int = 0, mouseHover:Bool = false)
	{
		for (item in menuItems.members)
		{
			item.animation.play('idle');
			item.centerOffsets();
		}

		if (huh != 0)
		{
			curSelected = FlxMath.wrap(curSelected + huh, 0, menuItems.length - 1);
		}

		if (huh != 0 || mouseHover)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		var spr:FlxSprite = menuItems.members[curSelected];
		spr.animation.play('selected');
		spr.centerOffsets();

		FlxG.camera.target = spr;
	}
}