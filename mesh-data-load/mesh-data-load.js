import {Client} from "@elastic/elasticsearch";
//import {Client8} from "@elastic/elasticsearch";
//import {Client} from "es8";
//require("dotenv").config(); //environment variables setup
//import "dotenv/config";
import * as dotenv from 'dotenv'
import * as fs from 'node:fs';
import * as path from 'node:path';
import assert from "node:assert";
import { parse } from "csv-parse/sync";
import { glob, globSync, globStream, globStreamSync, Glob } from 'glob';
import forceDetails from './police-force-details.json' with { type: 'json' };
import PoleDataStreet from './pole-data-street-schema.js';
import PoleDataStopSearch from './pole-data-stop-search-schema.js';

dotenv.config();

(async () => {
  try {
    let elsEndpoint = process.env.ELASTICSEARCH_ENDPOINT;
    let elsApiKey = process.env.ELASTICSEARCH_API_KEY;
    let dataBasePath = process.env.POLICE_DATA_BASEPATH;
    let dataEndYear = process.env.POLICE_DATA_END_YEAR;
    let dataStartYear = process.env.POLICE_DATA_START_YEAR;
    let meshClusterSize = process.env.DATA_MESH_CLUSTER_SIZE;
    let dataType = process.env.POLICE_DATA_TYPE;

    const elsClient = new Client({
      node: elsEndpoint,
      headers: {'custom': 'Accept:application/vnd.elasticsearch+json;compatible-with=8'},
      auth: {
        apiKey: elsApiKey
      },
      tls: {
        rejectUnauthorized: false
      }
    });

//console.log(await elsClient.info());

  let dataMonth = 1;
  let fileSuffix = dataType + ".csv";

  for (let x = dataStartYear; x <= dataEndYear; x++) {

    let dataYearPath = dataBasePath + x;

    for (let y = 1; y <=12; y++) {
      let dataPath = dataYearPath + "-" + String(y).padStart(2, '0');
console.log(dataPath);
      let fileItems = fs.readdirSync(dataPath,
        {
          recursive: true,
          withFileTypes: false
        }
      ).filter(fn => fn.endsWith(fileSuffix));

// If we have fewer files than meshClusterSize then set the loop size to the number of files:
      let fileLoopSize = meshClusterSize;
      if (fileItems.length < meshClusterSize) {
        fileLoopSize = fileItems.length;
      }

      for (let z = 0; z < fileLoopSize; z++) {
console.log(fileItems[z]);
        let filePath = path.join(dataPath, fileItems[z]);
        let input = fs.readFileSync(filePath);
        let records = parse(input, {
          columns: true,
          skip_empty_lines: true,
        });

        let force_reported_by = "";
        let force_falls_within = "";
// If we're reading stop and search files then we need to derive the Force name from the csv filename:
        if (dataType === "stop-and-search") {
          for (let force=0; force<forceDetails.length; force++) {
            if (fileItems[z].includes(forceDetails[force].CrimeFileName)) {
              force_reported_by = forceDetails[force].ForceName;
              force_falls_within = forceDetails[force].ForceName;
              break; // Exit the loop
            }
          }
        }
//continue;
//fs.writeFileSync("csv_records.json", JSON.stringify(records));

        let poleDataArray = [];

        for (let i=0; i<records.length; i++) {
          let poleData = {};

          if (dataType === "street") {
            poleData = PoleDataStreet();
            poleData.data.originator = records[i]["Reported by"];
            poleData.force.reported_by = records[i]["Reported by"];
            poleData.force.falls_within = records[i]["Falls within"];
            poleData.location.area = records[i].Location;
            poleData.location.geometric.lon = parseFloat(records[i].Longitude) || 0.0;
            poleData.location.geometric.lat = parseFloat(records[i].Latitude) || 0.0;
            poleData.lsoa.code = records[i]["LSOA code"];
            poleData.lsoa.name = records[i]["LSOA name"];
            poleData.event.date_time = records[i].Month;
            poleData.event.crime.date = records[i].Month;
            poleData.event.crime.id = records[i]["Crime ID"];
            poleData.event.crime.type = records[i]["Crime type"];
            poleData.event.crime.outcome = records[i]["Last outcome category"];
            poleData.event.crime.status = records[i].Context;
            poleDataArray.push(poleData);
          }
          else if (dataType === "stop-and-search") {
            poleData = PoleDataStopSearch();
            poleData.data.originator = force_reported_by;
            poleData.force.reported_by = force_reported_by;
            poleData.force.falls_within = force_falls_within;
            poleData.location.geometric.lon = parseFloat(records[i].Longitude) || 0.0;
            poleData.location.geometric.lat = parseFloat(records[i].Latitude) || 0.0;
            poleData.event.date_time = records[i].Date;
            poleData.event.stop_search.stop_nature = records[i].Type;
            poleData.event.stop_search.date_time = records[i].Date;
            poleData.event.stop_search.self_defined_ethnicity = records[i]["Self-defined ethnicity"];
            poleData.event.stop_search.officer_defined_ethnicity = records[i]["Officer-defined ethnicity"];
            poleData.event.stop_search.legislation = records[i].Legislation;
            poleData.event.stop_search.object_of_search = records[i]["Object of search"];
            poleData.event.stop_search.outcome = records[i].Outcome;
            poleData.person.gender = records[i].Gender;
            poleData.person.age_range = records[i]["Age range"];
            poleDataArray.push(poleData);
          }
          poleData = null;
        };

//console.log ("pole data array size: " + JSON.stringify(poleDataArray).length);
//console.log(poleDataArray[0].event.crime.id);
//fs.writeFileSync("crime.json", JSON.stringify(poleDataArray));

        let result = await elsClient.helpers.bulk({
          datasource: poleDataArray,
          onDocument (doc) {
            return {
              index: { _index: 'pole-data' }
            }
          },
  onDrop (doc) {
    console.log(doc)
  }
        });

console.log(JSON.stringify(result));
      }
    }
  };

  }
  catch (error) {
    console.log(error);
    process.exit(1);
  }
})();