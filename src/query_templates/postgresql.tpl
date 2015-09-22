define __LIMITA = "";
define __LIMITB = "";
define __LIMITC = "limit %d";
define _BEGIN = "INSERT INTO time_statistics (stream, query, template, seed, s_time) VALUES (" + [_STREAM] + ", " + [_QUERY] + ", '" + [_TEMPLATE] + "', " + [_SEED] + ", CURRENT_TIMESTAMP);";
define _END = "UPDATE time_statistics SET e_time = CURRENT_TIMESTAMP WHERE stream = " + [_STREAM] + " AND query = " + [_QUERY] + " AND template = '" + [_TEMPLATE] + "';";
