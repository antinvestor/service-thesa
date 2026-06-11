import 'package:antinvestor_api_profile/antinvestor_api_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/profile_repository.dart';

/// Cached provider that resolves a profile ID to a ProfileObject.
/// Returns null if the profile cannot be fetched.
final profileLookupProvider = FutureProvider.family<ProfileObject?, String>((
  ref,
  profileId,
) async {
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
  // Try properties.fields['au_name']
  if (profile.hasProperties()) {
    final nameField = profile.properties.fields['au_name'];
    if (nameField != null && nameField.hasStringValue()) {
      final name = nameField.stringValue;
      if (name.isNotEmpty) return name;
    }
    // Try given_name + family_name
    final given = profile.properties.fields['given_name'];
    final family = profile.properties.fields['family_name'];
    if (given != null &&
        given.hasStringValue() &&
        given.stringValue.isNotEmpty) {
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

/// Extract a description / quote from a ProfileObject.
String? profileDescription(ProfileObject profile) {
  if (!profile.hasProperties()) return null;
  // Try 'description', 'quote', 'bio' in order
  for (final key in ['description', 'quote', 'bio']) {
    final field = profile.properties.fields[key];
    if (field != null &&
        field.hasStringValue() &&
        field.stringValue.isNotEmpty) {
      return field.stringValue;
    }
  }
  return null;
}

/// A badge that displays a profile's avatar, name, and contact verification
/// status. Automatically fetches profile data from the API.
///
/// The badge auto-expands to show description and contacts when
/// sufficient horizontal space is available (> 300px).
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
      error: (_, _) => _buildFallback(context),
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
          child: Icon(
            Icons.person_outlined,
            size: compact ? 14 : 16,
            color: AppColors.onSurfaceMuted,
          ),
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
///
/// Uses [LayoutBuilder] to auto-expand when horizontal space > 300px,
/// showing description/quote and contact details alongside the name.
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

  int get _verifiedCount => profile.contacts.where((c) => c.verified).length;

  bool get _hasVerified => _verifiedCount > 0;

  @override
  Widget build(BuildContext context) {
    final badge = compact
        ? _buildCompact(context)
        : LayoutBuilder(
            builder: (context, constraints) {
              // Auto-expand when enough horizontal space is available.
              final expanded = constraints.maxWidth > 300;
              return expanded
                  ? _buildExpanded(context)
                  : _buildStandard(context);
            },
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

  /// Icon-only compact badge: avatar + name on one line.
  Widget _buildCompact(BuildContext context) {
    final name = profileDisplayName(profile);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _avatar(14.0),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              _verificationIcon(13),
            ],
          ),
        ),
      ],
    );
  }

  /// Standard badge: avatar + name + verification + contact count.
  Widget _buildStandard(BuildContext context) {
    final name = profileDisplayName(profile);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _avatar(16.0),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _verificationIcon(14),
                ],
              ),
              if (profile.contacts.isNotEmpty)
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
  }

  /// Expanded badge: avatar + name + description + contacts list.
  /// Shown when the badge has enough horizontal space (> 300px).
  Widget _buildExpanded(BuildContext context) {
    final name = profileDisplayName(profile);
    final description = profileDescription(profile);
    final contacts = profile.contacts.take(3).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _avatar(20.0),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name + verification
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _verificationIcon(14),
                ],
              ),
              // Description / quote
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceMuted,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Contact details
              if (contacts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    for (final contact in contacts)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            contact.type == ContactType.EMAIL
                                ? Icons.email_outlined
                                : Icons.phone_outlined,
                            size: 12,
                            color: AppColors.onSurfaceMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            contact.detail,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.onSurfaceMuted,
                            ),
                          ),
                          if (contact.verified) ...[
                            const SizedBox(width: 2),
                            Icon(
                              Icons.verified,
                              size: 11,
                              color: AppColors.success,
                            ),
                          ],
                        ],
                      ),
                    if (profile.contacts.length > 3)
                      Text(
                        '+${profile.contacts.length - 3} more',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar(double radius) {
    final name = profileDisplayName(profile);
    return CircleAvatar(
      radius: radius,
      backgroundColor: _typeColor.withValues(alpha: 0.15),
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: TextStyle(
          color: _typeColor,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _verificationIcon(double size) {
    if (_hasVerified) {
      return Icon(Icons.verified, size: size, color: AppColors.success);
    }
    if (profile.contacts.isNotEmpty) {
      return Icon(
        Icons.pending_outlined,
        size: size,
        color: AppColors.onSurfaceMuted,
      );
    }
    return const SizedBox.shrink();
  }
}
