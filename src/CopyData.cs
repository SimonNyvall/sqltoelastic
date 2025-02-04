﻿using Newtonsoft.Json.Linq;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace sqltoelastic
{
    class CopyData
    {
        public static async Task<bool> CopyRows(JObject config)
        {
            Log("Starting...");

            string dbprovider = config["dbprovider"]?.Value<string>() ?? string.Empty;
            string connstr = config["connstr"]?.Value<string>() ?? string.Empty;
            string sql = config["sql"]?.Value<string>() ?? string.Empty;

            string[] toupperfields = GetConfigArray(config, "toupperfields");
            string[] tolowerfields = GetConfigArray(config, "tolowerfields");
            string[] addconstantfields = GetConfigArray(config, "addconstantfields");
            string[] expandjsonfields = GetConfigArray(config, "expandjsonfields");
            string[] deescapefields = GetConfigArray(config, "deescapefields");

            JObject[] jsonrows;

            jsonrows = await SqlDB.GetRows(dbprovider, connstr, sql, toupperfields, tolowerfields,
                addconstantfields, expandjsonfields, deescapefields);

            Log($"Got {jsonrows.Length} rows.");

            string serverurl = config["serverurl"]?.Value<string>() ?? string.Empty;
            string username = config["username"]?.Value<string>() ?? string.Empty;
            string password = config["password"]?.Value<string>() ?? string.Empty;
            string indexname = config["indexname"]?.Value<string>() ?? string.Empty;
            string timestampfield = config["timestampfield"]?.Value<string>() ?? string.Empty;
            string idfield = config["idfield"]?.Value<string>() ?? string.Empty;
            string idprefix = config["idprefix"]?.Value<string>() ?? string.Empty;

            bool result = await Elastic.PutIntoIndex(serverurl, username, password, indexname, timestampfield, idfield, idprefix, jsonrows);

            return result;
        }

        static string[] GetConfigArray(JObject config, string fieldname)
        {
            return (config[fieldname] as JArray)?.Select(v => v.Value<string>() ?? string.Empty).ToArray() ?? Array.Empty<string>();
        }

        static void Log(string message)
        {
            Console.WriteLine(message);
        }
    }
}
