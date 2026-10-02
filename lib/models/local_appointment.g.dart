// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_appointment.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalAppointmentCollection on Isar {
  IsarCollection<LocalAppointment> get localAppointments => this.collection();
}

const LocalAppointmentSchema = CollectionSchema(
  name: r'LocalAppointment',
  id: -2760046061137350166,
  properties: {
    r'appointmentDate': PropertySchema(
      id: 0,
      name: r'appointmentDate',
      type: IsarType.dateTime,
    ),
    r'barberId': PropertySchema(
      id: 1,
      name: r'barberId',
      type: IsarType.string,
    ),
    r'barberName': PropertySchema(
      id: 2,
      name: r'barberName',
      type: IsarType.string,
    ),
    r'clientId': PropertySchema(
      id: 3,
      name: r'clientId',
      type: IsarType.string,
    ),
    r'clientName': PropertySchema(
      id: 4,
      name: r'clientName',
      type: IsarType.string,
    ),
    r'clientPhone': PropertySchema(
      id: 5,
      name: r'clientPhone',
      type: IsarType.string,
    ),
    r'lastSync': PropertySchema(
      id: 6,
      name: r'lastSync',
      type: IsarType.dateTime,
    ),
    r'notes': PropertySchema(
      id: 7,
      name: r'notes',
      type: IsarType.string,
    ),
    r'remoteId': PropertySchema(
      id: 8,
      name: r'remoteId',
      type: IsarType.string,
    ),
    r'serviceId': PropertySchema(
      id: 9,
      name: r'serviceId',
      type: IsarType.string,
    ),
    r'serviceName': PropertySchema(
      id: 10,
      name: r'serviceName',
      type: IsarType.string,
    ),
    r'servicePrice': PropertySchema(
      id: 11,
      name: r'servicePrice',
      type: IsarType.double,
    ),
    r'status': PropertySchema(
      id: 12,
      name: r'status',
      type: IsarType.string,
    )
  },
  estimateSize: _localAppointmentEstimateSize,
  serialize: _localAppointmentSerialize,
  deserialize: _localAppointmentDeserialize,
  deserializeProp: _localAppointmentDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _localAppointmentGetId,
  getLinks: _localAppointmentGetLinks,
  attach: _localAppointmentAttach,
  version: '3.1.0+1',
);

int _localAppointmentEstimateSize(
  LocalAppointment object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.barberId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.barberName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.clientId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.clientName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.clientPhone;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.notes;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.remoteId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.serviceId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.serviceName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.status.length * 3;
  return bytesCount;
}

void _localAppointmentSerialize(
  LocalAppointment object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.appointmentDate);
  writer.writeString(offsets[1], object.barberId);
  writer.writeString(offsets[2], object.barberName);
  writer.writeString(offsets[3], object.clientId);
  writer.writeString(offsets[4], object.clientName);
  writer.writeString(offsets[5], object.clientPhone);
  writer.writeDateTime(offsets[6], object.lastSync);
  writer.writeString(offsets[7], object.notes);
  writer.writeString(offsets[8], object.remoteId);
  writer.writeString(offsets[9], object.serviceId);
  writer.writeString(offsets[10], object.serviceName);
  writer.writeDouble(offsets[11], object.servicePrice);
  writer.writeString(offsets[12], object.status);
}

LocalAppointment _localAppointmentDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalAppointment();
  object.appointmentDate = reader.readDateTime(offsets[0]);
  object.barberId = reader.readStringOrNull(offsets[1]);
  object.barberName = reader.readStringOrNull(offsets[2]);
  object.clientId = reader.readStringOrNull(offsets[3]);
  object.clientName = reader.readStringOrNull(offsets[4]);
  object.clientPhone = reader.readStringOrNull(offsets[5]);
  object.id = id;
  object.lastSync = reader.readDateTimeOrNull(offsets[6]);
  object.notes = reader.readStringOrNull(offsets[7]);
  object.remoteId = reader.readStringOrNull(offsets[8]);
  object.serviceId = reader.readStringOrNull(offsets[9]);
  object.serviceName = reader.readStringOrNull(offsets[10]);
  object.servicePrice = reader.readDouble(offsets[11]);
  object.status = reader.readString(offsets[12]);
  return object;
}

P _localAppointmentDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readDouble(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localAppointmentGetId(LocalAppointment object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localAppointmentGetLinks(LocalAppointment object) {
  return [];
}

void _localAppointmentAttach(
    IsarCollection<dynamic> col, Id id, LocalAppointment object) {
  object.id = id;
}

extension LocalAppointmentQueryWhereSort
    on QueryBuilder<LocalAppointment, LocalAppointment, QWhere> {
  QueryBuilder<LocalAppointment, LocalAppointment, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalAppointmentQueryWhere
    on QueryBuilder<LocalAppointment, LocalAppointment, QWhereClause> {
  QueryBuilder<LocalAppointment, LocalAppointment, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension LocalAppointmentQueryFilter
    on QueryBuilder<LocalAppointment, LocalAppointment, QFilterCondition> {
  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      appointmentDateEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appointmentDate',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      appointmentDateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'appointmentDate',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      appointmentDateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'appointmentDate',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      appointmentDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'appointmentDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'barberId',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'barberId',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'barberId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'barberId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'barberId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'barberId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'barberId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'barberId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'barberId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'barberId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'barberId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'barberId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'barberName',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'barberName',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'barberName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'barberName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'barberName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'barberName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'barberName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'barberName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'barberName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'barberName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'barberName',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      barberNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'barberName',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'clientId',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'clientId',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'clientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'clientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'clientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'clientId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'clientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'clientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'clientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'clientId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'clientId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'clientId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'clientName',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'clientName',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'clientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'clientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'clientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'clientName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'clientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'clientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'clientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'clientName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'clientName',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'clientName',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientPhoneIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'clientPhone',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientPhoneIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'clientPhone',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientPhoneEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'clientPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientPhoneGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'clientPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientPhoneLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'clientPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientPhoneBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'clientPhone',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientPhoneStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'clientPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientPhoneEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'clientPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientPhoneContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'clientPhone',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientPhoneMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'clientPhone',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientPhoneIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'clientPhone',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      clientPhoneIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'clientPhone',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      lastSyncIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastSync',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      lastSyncIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastSync',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      lastSyncEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastSync',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      lastSyncGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastSync',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      lastSyncLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastSync',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      lastSyncBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastSync',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      notesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'notes',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      notesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'notes',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      notesEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      notesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      notesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      notesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'notes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      notesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      notesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      notesContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'notes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      notesMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'notes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      notesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      notesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'notes',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      remoteIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'remoteId',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      remoteIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'remoteId',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      remoteIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remoteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      remoteIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'remoteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      remoteIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'remoteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      remoteIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'remoteId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      remoteIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'remoteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      remoteIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'remoteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      remoteIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'remoteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      remoteIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'remoteId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      remoteIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remoteId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      remoteIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'remoteId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'serviceId',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'serviceId',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'serviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'serviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'serviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'serviceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'serviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'serviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'serviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'serviceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'serviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'serviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'serviceName',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'serviceName',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'serviceName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'serviceName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'serviceName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'serviceName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'serviceName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'serviceName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'serviceName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'serviceName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'serviceName',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      serviceNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'serviceName',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      servicePriceEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'servicePrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      servicePriceGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'servicePrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      servicePriceLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'servicePrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      servicePriceBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'servicePrice',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      statusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterFilterCondition>
      statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }
}

extension LocalAppointmentQueryObject
    on QueryBuilder<LocalAppointment, LocalAppointment, QFilterCondition> {}

extension LocalAppointmentQueryLinks
    on QueryBuilder<LocalAppointment, LocalAppointment, QFilterCondition> {}

extension LocalAppointmentQuerySortBy
    on QueryBuilder<LocalAppointment, LocalAppointment, QSortBy> {
  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByAppointmentDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appointmentDate', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByAppointmentDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appointmentDate', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByBarberId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barberId', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByBarberIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barberId', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByBarberName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barberName', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByBarberNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barberName', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByClientId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientId', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByClientIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientId', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByClientName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientName', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByClientNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientName', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByClientPhone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientPhone', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByClientPhoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientPhone', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByLastSync() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSync', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByLastSyncDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSync', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy> sortByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByRemoteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteId', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByRemoteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteId', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByServiceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serviceId', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByServiceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serviceId', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByServiceName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serviceName', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByServiceNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serviceName', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByServicePrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servicePrice', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByServicePriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servicePrice', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension LocalAppointmentQuerySortThenBy
    on QueryBuilder<LocalAppointment, LocalAppointment, QSortThenBy> {
  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByAppointmentDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appointmentDate', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByAppointmentDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appointmentDate', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByBarberId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barberId', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByBarberIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barberId', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByBarberName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barberName', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByBarberNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'barberName', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByClientId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientId', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByClientIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientId', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByClientName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientName', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByClientNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientName', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByClientPhone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientPhone', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByClientPhoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientPhone', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByLastSync() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSync', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByLastSyncDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSync', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy> thenByNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'notes', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByRemoteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteId', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByRemoteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remoteId', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByServiceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serviceId', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByServiceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serviceId', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByServiceName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serviceName', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByServiceNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serviceName', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByServicePrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servicePrice', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByServicePriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servicePrice', Sort.desc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QAfterSortBy>
      thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension LocalAppointmentQueryWhereDistinct
    on QueryBuilder<LocalAppointment, LocalAppointment, QDistinct> {
  QueryBuilder<LocalAppointment, LocalAppointment, QDistinct>
      distinctByAppointmentDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'appointmentDate');
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QDistinct>
      distinctByBarberId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'barberId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QDistinct>
      distinctByBarberName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'barberName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QDistinct>
      distinctByClientId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'clientId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QDistinct>
      distinctByClientName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'clientName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QDistinct>
      distinctByClientPhone({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'clientPhone', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QDistinct>
      distinctByLastSync() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSync');
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QDistinct> distinctByNotes(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'notes', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QDistinct>
      distinctByRemoteId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'remoteId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QDistinct>
      distinctByServiceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serviceId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QDistinct>
      distinctByServiceName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serviceName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QDistinct>
      distinctByServicePrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'servicePrice');
    });
  }

  QueryBuilder<LocalAppointment, LocalAppointment, QDistinct> distinctByStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }
}

extension LocalAppointmentQueryProperty
    on QueryBuilder<LocalAppointment, LocalAppointment, QQueryProperty> {
  QueryBuilder<LocalAppointment, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalAppointment, DateTime, QQueryOperations>
      appointmentDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'appointmentDate');
    });
  }

  QueryBuilder<LocalAppointment, String?, QQueryOperations> barberIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'barberId');
    });
  }

  QueryBuilder<LocalAppointment, String?, QQueryOperations>
      barberNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'barberName');
    });
  }

  QueryBuilder<LocalAppointment, String?, QQueryOperations> clientIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'clientId');
    });
  }

  QueryBuilder<LocalAppointment, String?, QQueryOperations>
      clientNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'clientName');
    });
  }

  QueryBuilder<LocalAppointment, String?, QQueryOperations>
      clientPhoneProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'clientPhone');
    });
  }

  QueryBuilder<LocalAppointment, DateTime?, QQueryOperations>
      lastSyncProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSync');
    });
  }

  QueryBuilder<LocalAppointment, String?, QQueryOperations> notesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'notes');
    });
  }

  QueryBuilder<LocalAppointment, String?, QQueryOperations> remoteIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'remoteId');
    });
  }

  QueryBuilder<LocalAppointment, String?, QQueryOperations>
      serviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serviceId');
    });
  }

  QueryBuilder<LocalAppointment, String?, QQueryOperations>
      serviceNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serviceName');
    });
  }

  QueryBuilder<LocalAppointment, double, QQueryOperations>
      servicePriceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'servicePrice');
    });
  }

  QueryBuilder<LocalAppointment, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }
}
