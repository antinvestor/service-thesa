import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/profile_repository.dart';

/// Cached provider that resolves a profile ID to a ProfileObject.
/// Returns null if the profile cannot be fetched.
final profileLookupProvider =
    FutureProvider.family<ProfileObject?, String>((ref, profileId) async {
  if (profileId.isEmpty) return null;
  try {
    final repo = await ref.watch(profileRepositoryProvider.future);
    return await repo.getById(profileId);
  } catch (_) {
    return null;
  }
});

/// Extract a display name from a ProfileObject.
String profileDisplayName(ProfileObject profile) {
  // Try properties.fields['name']
  if (profile.hasProperties()) {
    final nameField = profile.properties.fields['name'];
    if (nameField != null && nameField.hasStringValue()) {
      final name = nameField.stringValue;
      if (name.isNotEmpty) return name;
    }
    // Try given_name + family_name
    final given = profile.properties.fields['given_name'];
    final family = profile.properties.fields['family_name'];
    if (given != null && given.hasStringValue() && given.stringValue.isNotEmpty) {
      final parts = [
        given.stringValue,
        if (family != null && family.hasStringValue()) family.stringValue,
      ];
      return parts.join(' ');
    }
  }
  // Try first contact
  if (profile.contacts.isNotEmpty) {
    return profile.contacts.first.detail;
  }
  // Fallback
  return profile.id.length >= 8
      ? 'Profile ${profile.id.substring(0, 8)}'
      : profile.id;
}

/// A badge that displays a profile's avatar, name, and contact verification
/// status. Automatically fetches profile data from the API.
///
/// Use [ProfileBadge.fromProfile] when you already have the ProfileObject.
class ProfileBadge extends ConsumerWidget {
  const ProfileBadge({
    super.key,
    required this.profileId,
    this.compact = false,
    this.onTap,
  });

  final String profileId;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(profileLookupProvider(profileId));

    return asyncProfile.when(
      loading: () => _buildShimmer(context),
      error: (_, __) => _buildFallback(context),
      data: (profile) {
        if (profile == null) return _buildFallback(context);
        return ProfileBadgeContent(
          profile: profile,
          compact: compact,
          onTap: onTap,
        );
      },
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: compact ? 14 : 16,
          backgroundColor: AppColors.border,
        ),
        const SizedBox(width: 8),
        Container(
          width: 80,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: compact ? 14 : 16,
          backgroundColor: AppColors.onSurfaceMuted.withValues(alpha: 0.15),
          child: Icon(Icons.person_outlined,
              size: compact ? 14 : 16, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            profileId.length >= 12
                ? '${profileId.substring(0, 12)}...'
                : profileId,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: compact ? 11 : 12,
              color: AppColors.onSurfaceMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Renders the profile badge content when the profile data is available.
/// Can also be used directly when you already have a [ProfileObject].
class ProfileBadgeContent extends StatelessWidget {
  const ProfileBadgeContent({
    super.key,
    required this.profile,
    this.compact = false,
    this.onTap,
  });

  final ProfileObject profile;
  final bool compact;
  final VoidCallback? onTap;

  Color get _typeColor => switch (profile.type) {
        ProfileType.PERSON => AppColors.tertiary,
        ProfileType.INSTITUTION => AppColors.success,
        ProfileType.BOT => AppColors.warning,
        _ => AppColors.onSurfaceMuted,
      };

  int get _verifiedCount =>
      profile.contacts.where((c) => c.verified).length;

  bool get _hasVerified => _verifiedCount > 0;

  @override
  Widget build(BuildContext context) {
    final name = profileDisplayName(profile);
    final radius = compact ? 14.0 : 16.0;

    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: _typeColor.withValues(alpha: 0.15),
          child: Text(
            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
            style: TextStyle(
              color: _typeColor,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: compact ? 13 : 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (_hasVerified)
                    Icon(Icons.verified,
                        size: compact ? 13 : 14, color: AppColors.success)
                  else if (profile.contacts.isNotEmpty)
                    Icon(Icons.pending_outlined,
                        size: compact ? 13 : 14,
                        color: AppColors.onSurfaceMuted),
                ],
              ),
              if (!compact && profile.contacts.isNotEmpty)
                Text(
                  '${profile.contacts.length} contact${profile.contacts.length == 1 ? '' : 's'}'
                  ' · $_verifiedCount verified',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: badge,
        ),
      );
    }
    return badge;
  }
}
