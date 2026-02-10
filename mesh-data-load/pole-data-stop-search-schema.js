function PoleDataStopSearch() {
return {
    data: {
      original: "",
      source: "police-stop-and-search",
      originator: "",
      pole_type: "event"
    },
    log: {
      file: {
        path: ""
      }
    },
    host: {},
    force: {
      reported_by: "",
      falls_within: ""
    },
    location: {
      area: "",
      geometric: {
        lon: 0,
        lat: 0
      }
    },
    person: {
      gender: "",
      age_range: ""
    },
    date_of_birth: "",
    event: {
      stop_search: {
        stop_nature: "",
        self_defined_ethnicity: "",
        officer_defined_ethnicity: "",
        legislation: "",
        date_time: "",
        object_of_search: "",
        outcome: ""
      },
      type: "stop_search"
    }
  }
}

export default PoleDataStopSearch;
