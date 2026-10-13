// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_repository_impl.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchResultDto _$SearchResultDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SearchResultDto', json, ($checkedConvert) {
      final val = SearchResultDto(
        lessonId: $checkedConvert('lessonId', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        nodeId: $checkedConvert('nodeId', (v) => v as String),
        nodeTitle: $checkedConvert('nodeTitle', (v) => v as String),
        levelLabel: $checkedConvert('levelLabel', (v) => v as String),
        statusTitle: $checkedConvert('statusTitle', (v) => v as String),
        state: $checkedConvert('state', (v) => v as String),
      );
      return val;
    });
