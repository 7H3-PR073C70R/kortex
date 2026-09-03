import 'package:equatable/equatable.dart';

/// Represents a specialized peer course/track study community hub.
class StudyCommunityEntity extends Equatable {
  const StudyCommunityEntity({
    required this.id,
    required this.courseCode,
    required this.title,
    required this.department,
    required this.memberCount,
    required this.activeRoomsCount,
    required this.forumThreadsCount,
    this.isUserMember = true,
    this.isFoundingMember = false,
    this.activeRoomId,
    this.activeRoomTitle,
    this.createdAt,
  });

  final String id;
  final String courseCode; // e.g. "WAEC-CHEM", "CHE-301", "JAMB-PHY"
  final String title;
  final String department;
  final int memberCount;
  final int activeRoomsCount;
  final int forumThreadsCount;
  final bool isUserMember;
  final bool isFoundingMember;
  final String? activeRoomId;
  final String? activeRoomTitle;
  final DateTime? createdAt;

  StudyCommunityEntity copyWith({
    String? id,
    String? courseCode,
    String? title,
    String? department,
    int? memberCount,
    int? activeRoomsCount,
    int? forumThreadsCount,
    bool? isUserMember,
    bool? isFoundingMember,
    String? activeRoomId,
    String? activeRoomTitle,
    DateTime? createdAt,
  }) {
    return StudyCommunityEntity(
      id: id ?? this.id,
      courseCode: courseCode ?? this.courseCode,
      title: title ?? this.title,
      department: department ?? this.department,
      memberCount: memberCount ?? this.memberCount,
      activeRoomsCount: activeRoomsCount ?? this.activeRoomsCount,
      forumThreadsCount: forumThreadsCount ?? this.forumThreadsCount,
      isUserMember: isUserMember ?? this.isUserMember,
      isFoundingMember: isFoundingMember ?? this.isFoundingMember,
      activeRoomId: activeRoomId ?? this.activeRoomId,
      activeRoomTitle: activeRoomTitle ?? this.activeRoomTitle,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    courseCode,
    title,
    department,
    memberCount,
    activeRoomsCount,
    forumThreadsCount,
    isUserMember,
    isFoundingMember,
    activeRoomId,
    activeRoomTitle,
    createdAt,
  ];
}
