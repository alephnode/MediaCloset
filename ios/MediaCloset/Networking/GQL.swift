//
//  Networking/GQL.swift
//  MediaCloset
//
//  Created by Stephen Ward on 10/11/25.
//
enum GQL {
    // LIST RECORDS (with optional search)
    static let queryRecords = """
    query Records($pattern: String!, $limit: Int = 50, $offset: Int = 0) {
      records(
        where: {
          _or: [
            { artist: { _ilike: $pattern } },
            { album:  { _ilike: $pattern } }
          ]
        },
        limit: $limit,
        offset: $offset,
        order_by: [{ artist: asc }, { year: asc }]
      ) {
        id artist album year color_variants genres cover_url
      }
    }
    """

    // RECORD DETAIL (+ tracks)
    static let recordDetail = """
    query Record($id: uuid!) {
      records_by_pk(id: $id) {
        id
        artist
        album
        label
        catalog_number
        year
        color_variants
        genres
        country
        upc
        cover_url
        condition
        sleeve_condition
        notes
        location
        tracks(order_by: { track_no: asc }) {
          id
          title
          duration_sec
          track_no
        }
      }
    }
    """

    // INSERT ONE RECORD (with nested tracks)
    static let insertRecord = """
    mutation InsertRecord($object: records_insert_input!) {
      insert_records_one(object: $object) {
        id
      }
    }
    """
    
    // Update an existing record by primary key
    static let updateRecord = """
    mutation UpdateRecord($id: uuid!, $set: records_set_input!) {
      update_records_by_pk(pk_columns: {id: $id}, _set: $set) { id }
    }
    """

    // VHS LIST
    static let queryVHSList = """
    query VHSList($pattern: String = "%%", $limit: Int = 50, $offset: Int = 0) {
      vhs(
        where: {
          _or: [
            { title:    { _ilike: $pattern } },
            { director: { _ilike: $pattern } }
          ]
        },
        limit: $limit,
        offset: $offset,
        order_by: [{ title: asc }]
      ) {
        id
        title
        director
        year
        genre
        cover_url
      }
    }
    """

    // VHS INSERT
    static let insertVHS = """
    mutation InsertVHS($object: vhs_insert_input!) {
      insert_vhs_one(object: $object) { id }
    }
    """

    // VHS UPDATE
    static let updateVHS = """
    mutation UpdateVHS($id: uuid!, $set: vhs_set_input!) {
      update_vhs_by_pk(pk_columns: {id: $id}, _set: $set) { id }
    }
    """

    // VHS DETAIL
    static let vhsDetail = """
    query VHSDetail($id: uuid!) {
      vhs_by_pk(id: $id) {
        id
        title
        director
        year
        genre
        cover_url
        notes
      }
    }
    """

}
