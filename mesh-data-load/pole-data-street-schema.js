function PoleDataStreet() {
return {
    data: {
      original: "",
      source: "police-street-crime",
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
    lsoa: {
      code: "",
      name: ""
    },
    event: {
      crime: {
        date: "",
        id: "",
        type: "",
        outcome: "",
        status: "",
        date_time: ""
      },
      type: "crime"
    }
  }
}

export default PoleDataStreet;
