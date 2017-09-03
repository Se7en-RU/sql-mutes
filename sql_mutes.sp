#pragma semicolon 1

#include <sourcemod>
#include <basecomm>

#pragma newdecls required

public Plugin myinfo = {
	name = "SQL Mutes",
	author = "Se7en",
	version = "1.1",
	url = "https://csgo.su"
}

Database g_Database;
DBStatement g_AddMuteQuery;
DBStatement g_RemoveMuteQuery;

bool g_bClientMuted[MAXPLAYERS + 1];

public void OnPluginStart() {
	char error[256];

	g_Database = SQL_Connect("mutes", true, error, sizeof(error));
	SQL_FastQuery(g_Database, "CREATE TABLE IF NOT EXISTS 'mutes' (steam_id VARCHAR(32) NOT NULL PRIMARY KEY);");
	
	if (!g_Database) {
		SetFailState("Could not connect to mutes database: %s", error);
	}
	
	g_AddMuteQuery = SQL_PrepareQuery(g_Database, "INSERT INTO mutes (steam_id) VALUES (?);", error, sizeof(error));
	g_RemoveMuteQuery = SQL_PrepareQuery(g_Database, "DELETE FROM mutes WHERE steam_id= ?;", error, sizeof(error));
	
	if (!g_AddMuteQuery) {
		SetFailState("Could not create prepared statement g_AddMuteQuery: %s", error);
	}
	
	if (!g_RemoveMuteQuery) {
		SetFailState("Could not create prepared statement g_RemoveMuteQuery: %s", error);
	}
	
	HookEvent("cs_match_end_restart", RestartRound);

}

public void OnPluginEnd() {
	delete g_AddMuteQuery;
	delete g_RemoveMuteQuery;
}

public void OnMapEnd() {
	if (g_Database) {
		SQL_FastQuery(g_Database, "DELETE FROM 'mutes';");
	}
}

public Action RestartRound(Handle event, const char[] name, bool dbc) {
	if (g_Database) {
		SQL_FastQuery(g_Database, "DELETE FROM 'mutes';");
	}
}

public void BaseComm_OnClientMute(int client, bool muteState) {
	char steam_id[32];
	GetClientAuthId(client, AuthId_Steam2, steam_id, sizeof(steam_id));
	
	if(muteState == true) {
			g_AddMuteQuery.BindString(0, steam_id, false);
			SQL_Execute(g_AddMuteQuery);
	} else {
		g_RemoveMuteQuery.BindString(0, steam_id, false);
		SQL_Execute(g_RemoveMuteQuery);
	}
}

public void OnClientConnected(int client) {
	g_bClientMuted[client] = false;
}

public void OnClientAuthorized(int client) {
	char query[1024];
	char steam_id[32];
	GetClientAuthId(client, AuthId_Steam2, steam_id, sizeof(steam_id));
	
	Format(query, sizeof(query), "SELECT steam_id FROM mutes WHERE steam_id = '%s' LIMIT 1", steam_id);
	g_Database.Query(OnQueriedClientMute, query, GetClientUserId(client));
}

public void OnQueriedClientMute(Database database, DBResultSet results, const char[] error, int userid) {
	int client = GetClientOfUserId(userid);
		
	if (client && results && results.RowCount) {
		g_bClientMuted[client] = true;
		
		if (IsClientInGame(client)) {
			OnClientPutInServer(client);
		}
	}
}

public void OnClientPutInServer(int client) {
	if (g_bClientMuted[client]) {
		BaseComm_SetClientMute(client, true);
	}
}