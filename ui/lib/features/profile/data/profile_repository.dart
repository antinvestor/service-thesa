import 'package:antinvestor_api_common/antinvestor_api_common.dart'
    show STATE, Struct;
import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/connect_client.dart';

/// Repository wrapping [ProfileServiceClient] for all profile operations.
class ProfileRepository {
  ProfileRepository(this._client);

  final ProfileServiceClient _client;

  // ── Profiles ─────────────────────────────────────────────────────────────

  Future<ProfileObject> getById(String id) async =>
      (await _client.getById(GetByIdRequest(id: id))).data;

  Future<ProfileObject> getByContact(String contact) async =>
      (await _client
              .getByContact(GetByContactRequest(contact: contact)))
          .data;

  Future<List<ProfileObject>> search({
    String query = '',
  }) async {
    final items = <ProfileObject>[];
    await for (final response in _client.search(SearchRequest(
      query: query,
    ))) {
      items.addAll(response.data);
    }
    return items;
  }

  Future<ProfileObject> create({
    required ProfileType type,
    required String contact,
    Struct? properties,
  }) async =>
      (await _client.create(CreateRequest(
        type: type,
        contact: contact,
        properties: properties,
      )))
          .data;

  Future<ProfileObject> update({
    required String id,
    Struct? properties,
    STATE? state,
  }) async =>
      (await _client.update(UpdateRequest(
        id: id,
        properties: properties,
        state: state,
      )))
          .data;

  Future<ProfileObject> merge({
    required String id,
    required String mergeId,
  }) async =>
      (await _client.merge(MergeRequest(id: id, mergeid: mergeId))).data;

  // ── Contacts ─────────────────────────────────────────────────────────────

  Future<({ProfileObject profile, String verificationId})> addContact({
    required String profileId,
    required String contact,
    Struct? extras,
  }) async {
    final response = await _client.addContact(AddContactRequest(
      id: profileId,
      contact: contact,
      extras: extras,
    ));
    return (
      profile: response.data,
      verificationId: response.verificationId,
    );
  }

  Future<ContactObject> createContact({
    required String profileId,
    required String contact,
    Struct? extras,
  }) async =>
      (await _client.createContact(CreateContactRequest(
        id: profileId,
        contact: contact,
        extras: extras,
      )))
          .data;

  Future<({String id, bool success})> createContactVerification({
    required String profileId,
    required String contactId,
    String code = '',
    String durationToExpire = '',
  }) async {
    final response = await _client
        .createContactVerification(CreateContactVerificationRequest(
      id: profileId,
      contactId: contactId,
      code: code,
      durationToExpire: durationToExpire,
    ));
    return (id: response.id, success: response.success);
  }

  Future<({String id, bool success, int checkAttempts})> checkVerification({
    required String verificationId,
    required String code,
  }) async {
    final response =
        await _client.checkVerification(CheckVerificationRequest(
      id: verificationId,
      code: code,
    ));
    return (
      id: response.id,
      success: response.success,
      checkAttempts: response.checkAttempts,
    );
  }

  Future<ProfileObject> removeContact(String contactId) async =>
      (await _client
              .removeContact(RemoveContactRequest(id: contactId)))
          .data;

  // ── Addresses ────────────────────────────────────────────────────────────

  Future<ProfileObject> addAddress({
    required String profileId,
    required AddressObject address,
  }) async =>
      (await _client.addAddress(AddAddressRequest(
        id: profileId,
        address: address,
      )))
          .data;

  // ── Relationships ────────────────────────────────────────────────────────

  Future<List<RelationshipObject>> listRelationships({
    required String peerName,
    required String peerId,
    int count = 50,
    bool invertRelation = false,
  }) async {
    final items = <RelationshipObject>[];
    await for (final response
        in _client.listRelationship(ListRelationshipRequest(
      peerName: peerName,
      peerId: peerId,
      count: count,
      invertRelation: invertRelation,
    ))) {
      items.addAll(response.data);
    }
    return items;
  }

  Future<RelationshipObject> addRelationship({
    required String parent,
    required String parentId,
    required String child,
    required String childId,
    RelationshipType type = RelationshipType.MEMBER,
    Struct? properties,
  }) async =>
      (await _client.addRelationship(AddRelationshipRequest(
        parent: parent,
        parentId: parentId,
        child: child,
        childId: childId,
        type: type,
        properties: properties,
      )))
          .data;

  Future<RelationshipObject> deleteRelationship({
    required String id,
    String? parentId,
  }) async =>
      (await _client.deleteRelationship(DeleteRelationshipRequest(
        id: id,
        parentId: parentId,
      )))
          .data;

  // ── Roster ───────────────────────────────────────────────────────────────

  Future<List<RosterObject>> searchRoster({
    required String profileId,
    String query = '',
    int count = 50,
  }) async {
    final items = <RosterObject>[];
    await for (final response
        in _client.searchRoster(SearchRosterRequest(
      profileId: profileId,
      query: query,
      count: count,
    ))) {
      items.addAll(response.data);
    }
    return items;
  }

  Future<List<RosterObject>> addRoster(List<RawContact> contacts) async =>
      (await _client.addRoster(AddRosterRequest(data: contacts))).data;

  Future<RosterObject> removeRoster(String id) async =>
      (await _client.removeRoster(RemoveRosterRequest(id: id))).roster;
}

// ─── Provider ────────────────────────────────────────────────────────────────

final profileRepositoryProvider =
    FutureProvider<ProfileRepository>((ref) async {
  final client = await ref.watch(profileServiceClientProvider.future);
  return ProfileRepository(client);
});
