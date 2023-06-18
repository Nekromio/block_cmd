#pragma semicolon 1
#pragma newdecls required

ArrayList
	hArray[3];

ConVar
	cvNoSpec,
	cvTimer;

bool
	bBlockGame[MAXPLAYERS+1];

int
	iHook[MAXPLAYERS+1],
	iHook2[MAXPLAYERS+1];

char
	sFile[PLATFORM_MAX_PATH];

public Plugin myinfo = 
{
	name = "Block CMD",
	author = "Nek.'a 2x2 | ggwp.site ",
	description = "блокировка игры при не приемлемых значений команд",
	version = "1.0.7",
	url = "https://ggwp.site/"
};

public void OnPluginStart()
{
	cvNoSpec = CreateConVar("sm_bloccmd_nospec", "1", "Перекидывать ли в спеки игроков с запрещенной командой?", _, true, 0.0);
	cvTimer = CreateConVar("sm_bloccmd_timer", "5.0", "С какой переодичностью будет идти проверка игроков? (в секундах)");
	
	hArray[0] = new ArrayList(ByteCountToCells(64));
	hArray[1] = new ArrayList(ByteCountToCells(64));
	hArray[2] = new ArrayList(ByteCountToCells(64));
	
	char sPath[PLATFORM_MAX_PATH]; Handle hFile;
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/block_cmd.ini");
	
	KeyValues hKeyValues = new KeyValues("ListCmd");
	if(!hKeyValues.ImportFromFile(sPath))
		PrintToChatAll("Файл не был загружен [%s]", sPath);
		
	if(!FileExists(sPath))
	{
		hFile = OpenFile(sPath, "w");
		CloseHandle(hFile);
	}
	
	AddCommandListener(Command_JoinTeam, "jointeam");
	
	CheckSettings(hKeyValues);
	
	BuildPath(Path_SM, sFile, sizeof(sFile), "logs/block_cmd.log");
	
	RegConsoleCmd("sm_bl", CmdCheckBlock);
	
	AutoExecConfig(true, "block_cmd");
}

public void OnMapStart()
{
	CreateTimer(cvTimer.FloatValue, Timer_CheckClient, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPutInServer(int client)
{
	CmdList(client);
}

public void OnClientDisconnect(int client)
{
	bBlockGame[client] = false;
}

void CheckSettings(KeyValues hKeyValues)
{
	hKeyValues.Rewind();
	hKeyValues.JumpToKey("BlockCmd", false);

	char sKey[32], sValue[16], sKeyMin[32];
	
	if(hKeyValues.GotoFirstSubKey(false))
	{
		do
		{
			if(hKeyValues.GetSectionName(sKey, sizeof(sKey)))
			{
				if(hKeyValues.GotoFirstSubKey(false))
				{
					int iCmdChat;
					do 
					{
						if(hKeyValues.GetSectionName(sKeyMin, sizeof(sKeyMin)))
						{
							hKeyValues.GetString(NULL_STRING, sValue, sizeof(sValue));

							if(!iCmdChat)
							{
								hArray[0].PushString(sKey);
								hArray[1].PushString(sValue);
							}
							else
							{
								hArray[2].PushString(sValue);
							}
							iCmdChat++;
						}
						
					} while(hKeyValues.GotoNextKey(false));
					hKeyValues.GoBack();
				}
			}
		} while( hKeyValues.GotoNextKey(false));
	}
	KvRewind(hKeyValues);
	CloseHandle(hKeyValues);
}

Action Timer_CheckClient(Handle hTimer)
{
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i))
		iHook[i] = 0;
	CheckClientAll();
	return Plugin_Changed;
}

Action CmdCheckBlock(int client, any args)
{
	CheckClientAll();
	
	return Plugin_Changed;
}

void CheckClientAll()
{
	char sConVar[32];

	for(int i = 1; i <=MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i))
	{
		for(int d; d < GetArraySize(hArray[0]); d++)
		{
			GetArrayString(hArray[0], d, sConVar, sizeof(sConVar));
			QueryClientConVar(i, sConVar, OnConVarQueryFinished, d) == QUERYCOOKIE_FAILED;
		}
	}
}

void CmdList(int client)
{
	if(IsFakeClient(client))
		return;

	char sConVar[32];
	for(int i; i < GetArraySize(hArray[0]); i++)
	{
		GetArrayString(hArray[0], i, sConVar, sizeof(sConVar));
		QueryClientConVar(client, sConVar, OnConVarQueryFinished, i) == QUERYCOOKIE_FAILED;
	}
}

void OnConVarQueryFinished(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any serial)
{
	if(!IsClientValid(client))
		return;
		
	if(result == ConVarQuery_NotFound)
		LogError("Игрок [%N] | такой команды [%s] не существует", client, cvarName);
	
	else if(result == ConVarQuery_NotValid)
		LogError("Была найдена консольная команда с тем же именем [%s], но в ней нет convar", client, cvarName);
	
	else if(result == ConVarQuery_Protected)
		LogError("Игрок [%N] | convar [%s] был найден, но он защищен. Сервер не может получить его значение", client, cvarName);
	
	char sConVars[3][64];
	GetArrayString(hArray[0], serial, sConVars[0], sizeof(sConVars[]));		//проверяемая команда
	GetArrayString(hArray[1], serial, sConVars[1], sizeof(sConVars[]));		//минимальное значение команды
	GetArrayString(hArray[2], serial, sConVars[2], sizeof(sConVars[]));		//максимальное значение команды

	switch(GetTypeString(cvarValue))
	{
		case 0:
		{
			CheckCvars(client, sConVars[0], sConVars[1], sConVars[2], _, 0);
			return;
		}

		case 1:
		{
			if(StringToFloat(sConVars[1]) > StringToFloat(cvarValue) || StringToFloat(cvarValue) > StringToFloat(sConVars[2]))
			{
				CheckCvars(client, sConVars[0], sConVars[1], sConVars[2], cvarValue, 1);
				return;
			}
		}
		
		case 2:
		{
			if(StringToInt(sConVars[1]) > StringToInt(cvarValue) || StringToInt(cvarValue) > StringToInt(sConVars[2]))
			{
				CheckCvars(client, sConVars[0], sConVars[1], sConVars[2], cvarValue, 2);
				return;
			}
		}
	}
	if(cvNoSpec.BoolValue)
	{
		if(!iHook[client] && iHook2[client] > 0)
		{
			char sText[512];
			Format(sText, sizeof(sText), "Теперь вы [%N] можете играть !", client);
			ShowMOTDPanel(client, "Меню с подсказкой", sText, MOTDPANEL_TYPE_TEXT);
			bBlockGame[client] = false;
			iHook2[client] = 0;
		}
	}
}

void CheckCvars(int client, char[] CvarName, char[] cvarValueMin, char[] cvarValueMax, const char[] cvarValueClient = "", int index)
{
	char sIp[16], sSteamid[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamid, sizeof(sSteamid));
	GetClientIP(client, sIp, sizeof(sIp));

	if(!index)
	{
		LogToFile(sFile, "Игрок [%N]/[%s]/[%s] использует запрещённое значение команды %s, он попытался сжульничать и использовать текст !",
		 client, sIp, sSteamid, CvarName);
	}
	else
	{
		LogToFile(sFile, "Игрок [%N]/[%s]/[%s] использует запрещённое значение команды %s %s, разрешенные пределы [%s]/[%s]",
				client, sIp, sSteamid, CvarName, cvarValueClient, cvarValueMin, cvarValueMax);
	}

	if(!cvNoSpec.BoolValue)
	{
		KickClient(client, "У вас не допустимое значение [%s %s], разрешенные пределы [%s]/[%s]", CvarName, cvarValueClient, cvarValueMin, cvarValueMax);
		return;
	}
	
	ArrayFunc(client);
	if(bBlockGame[client])
	{
		ChangeClientTeam(client, 1);
		DisplayPanel(client, CvarName, cvarValueClient, cvarValueMin, cvarValueMax, index);
	}
}

void ArrayFunc(int client)
{
	bBlockGame[client] = true;
	if(bBlockGame[client] == true)
	{
		iHook[client]++;
	}
	iHook2[client] = 1;
}

void DisplayPanel(int client, char[] sVars, const char[] Value, char[] CvarMin, char[] CvarMax, int index)
{
	char sText[512];

	switch(index)
	{
		case 0:	Format(sText, sizeof(sText), "У вас [%N] запрещенное значение команды %s ! \nИзмени на [%d]/[%d] ",
		 client, sVars, StringToInt(CvarMin), StringToInt(CvarMax));
		case 1: Format(sText, sizeof(sText), "У вас [%N] запрещенное значение команды %s %.3f\nИзмени [%.3f]/[%.3f] И через секунду играй!",
		 client, sVars, StringToFloat(Value), StringToFloat(CvarMin), StringToFloat(CvarMax));
		case 2: Format(sText, sizeof(sText), "У вас [%N] запрещенное значение команды %s %d\nИзмени [%d]/[%d] И через секунду играй!",
		 client, sVars, StringToInt(Value), StringToInt(CvarMin), StringToInt(CvarMax));
	}
	ShowMOTDPanel(client, "Меню с подсказкой", sText, MOTDPANEL_TYPE_TEXT);
}

Action Command_JoinTeam(int client, char[] sCommand, int args)
{
	char sArg[8];
	GetCmdArg(1, sArg, sizeof(sArg));
	int iOldTeam = GetClientTeam(client);

	if(bBlockGame[client] && (iOldTeam == 0 || iOldTeam == 1))
	{
		ChangeClientTeam(client, 1);
		return Plugin_Handled;
	}
	
	return Plugin_Changed;
}

int GetTypeString(const char[] string)
{
	int len = strlen(string), i = -1;
	if (22 < len) return 0;
	if (string[0] == 45)
	{
		if (len == 1) return 0;
		i = 0;
	}
	while (string[++i]) if (string[i] < 48 || 57 < string[i]) return string[i] == 46 && 47 < string[++i] && string[i] < 58 ? 1 : 0;
	return 2;
}

bool IsClientValid(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client);
}