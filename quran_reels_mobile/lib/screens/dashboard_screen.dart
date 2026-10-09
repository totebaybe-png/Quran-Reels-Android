import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/theme/app_theme.dart';
import '../models/workflow_run.dart';
import '../services/github_service.dart';
import 'setup_wizard_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _githubUser;
  String? _githubRepo;
  String? _githubToken;
  String? _githubBranch;

  bool _isLoading = true;
  bool _isTriggeringRun = false;
  List<WorkflowRun> _recentRuns = [];
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  Duration _timeUntilNextRun = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startTimers();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimers() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
    // Auto-refresh runs every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchRuns());
  }

  void _updateCountdown() {
    final now = DateTime.now().toUtc();
    // Schedule hours: 00:22, 05:41, 11:33, 17:19 UTC
    final schedules = [
      DateTime.utc(now.year, now.month, now.day, 0, 22),
      DateTime.utc(now.year, now.month, now.day, 5, 41),
      DateTime.utc(now.year, now.month, now.day, 11, 33),
      DateTime.utc(now.year, now.month, now.day, 17, 19),
      DateTime.utc(now.year, now.month, now.day + 1, 0, 22),
    ];

    final nextRun = schedules.firstWhere((s) => s.isAfter(now));
    setState(() {
      _timeUntilNextRun = nextRun.difference(now);
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _githubUser = await SecureStorageService.getGithubUser();
    _githubRepo = await SecureStorageService.getTargetRepo();
    _githubToken = await SecureStorageService.getGithubToken();
    _githubBranch = await SecureStorageService.getDefaultBranch() ?? 'main';

    await _fetchRuns();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchRuns() async {
    if (_githubToken == null || _githubUser == null || _githubRepo == null) return;
    try {
      final runs = await GithubService.getLatestRuns(
        token: _githubToken!,
        owner: _githubUser!,
        repo: _githubRepo!,
      );
      if (mounted) {
        setState(() => _recentRuns = runs);
      }
    } catch (_) {}
  }

  Future<void> _triggerInstantRun() async {
    if (_githubToken == null || _githubUser == null || _githubRepo == null) return;

    setState(() => _isTriggeringRun = true);
    try {
      final success = await GithubService.triggerWorkflowDispatch(
        token: _githubToken!,
        owner: _githubUser!,
        repo: _githubRepo!,
        workflowFileName: AppConstants.workflowFileName,
        branch: _githubBranch ?? 'main',
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🚀 تم إطلاق مهمة التوليد بنجاح! يستغرق إنتاج ورفع الريل على خوادم GitHub '
              'المجانية عادةً من 3 إلى 10 دقائق، وسيظهر في السجلات بالأسفل.',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.statusSuccess,
          ),
        );
        await Future.delayed(const Duration(seconds: 4));
        await _fetchRuns();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذّر إطلاق المهمة. تأكد من تفعيل GitHub Actions على المستودع '
              '(Settings → Actions → General) وأن الفرع "${_githubBranch ?? 'main'}" موجود.',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
            backgroundColor: AppTheme.statusError,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل الإطلاق: $e', style: GoogleFonts.cairo(color: Colors.white)),
          backgroundColor: AppTheme.statusError,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTriggeringRun = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.goldPrimary.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: AppTheme.goldLight),
            const SizedBox(width: 10),
            Text(
              'حول التطبيق',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppTheme.goldLight),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مولد ريلز وشورتس القرآن الكريم السحابي',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'الإصدار: ${AppConstants.appVersion}',
              style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'فكرة وتطوير: ${AppConstants.authorName}',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.goldLight),
                  ),
                  Text(
                    'صاحب: ${AppConstants.channelName}',
                    style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'نية العمل: صدقة جارية لوجه الله تعالى 🌿',
                    style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.statusSuccess),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openUrl(AppConstants.channelUrl);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.subscriptions_rounded, color: Colors.white, size: 18),
                label: Text(
                  'اشترك في قناة المطور (${AppConstants.channelName})',
                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openUrl(AppConstants.tutorialVideoUrl);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.goldPrimary),
                ),
                icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.goldLight, size: 18),
                label: Text(
                  'مشاهدة فيديو الشرح على يوتيوب',
                  style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.goldLight, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إغلاق', style: GoogleFonts.cairo(color: AppTheme.goldLight)),
          ),
        ],
      ),
    );
  }

  void _confirmResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppTheme.statusWarning.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.statusWarning),
            const SizedBox(width: 8),
            Text(
              'إعادة ضبط الربط؟',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppTheme.goldLight),
            ),
          ],
        ),
        content: Text(
          'هل تريد مسح بيانات الاعتماد المخزنة على هذا الهاتف والعودة لمعالج الإعداد؟\n\n'
          '(ملاحظة: السيرفرات السحابية وقناتك على يوتيوب ستستمر في النشر حتى لو أعدت الضبط هنا).',
          style: GoogleFonts.cairo(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusWarning),
            onPressed: () async {
              Navigator.pop(ctx);
              await SecureStorageService.clearAll();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
              );
            },
            child: Text('نعم، إعادة الضبط', style: GoogleFonts.cairo(color: AppTheme.bgDark, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repoUrl = 'https://github.com/$_githubUser/$_githubRepo';

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text('لوحة تحكم ريلز القرآن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: AppTheme.goldLight),
            onPressed: _showAboutDialog,
            tooltip: 'حول التطبيق والحقوق',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.goldLight),
            onPressed: _fetchRuns,
            tooltip: 'تحديث السجلات',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
            onPressed: _confirmResetDialog,
            tooltip: 'إعادة الضبط',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.goldPrimary)))
          : RefreshIndicator(
              onRefresh: _fetchRuns,
              color: AppTheme.goldPrimary,
              backgroundColor: AppTheme.bgCard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                children: [
                  // 1. Status Banner
                  _buildStatusCard(repoUrl),
                  const SizedBox(height: 16),

                  // 2. Countdown & Schedule Card
                  _buildScheduleCard(),
                  const SizedBox(height: 16),

                  // 3. Instant Reel Action Button
                  _buildInstantTriggerButton(),
                  const SizedBox(height: 24),

                  // 4. Recent Video Upload Runs
                  _buildRunsSection(),
                  const SizedBox(height: 20),

                  // 5. Developer & Video Banner Footer
                  _buildDashboardFooter(),
                ],
              ),
            ),
    );
  }

  /// Derives the channel's real health from the latest workflow runs instead of
  /// always painting a green dot. GitHub Actions is the single source of truth.
  ({Color color, String label}) _channelHealth() {
    if (_recentRuns.isEmpty) {
      return (
        color: AppTheme.statusWarning,
        label: 'في انتظار أول عملية نشر سحابية...'
      );
    }

    final latest = _recentRuns.first;
    final age = DateTime.now().toUtc().difference(latest.createdAt);

    if (latest.isSuccess) {
      if (age.inHours < 48) {
        return (
          color: AppTheme.statusSuccess,
          label: 'القناة نشطة وتعمل تلقائياً 24/7'
        );
      }
      return (
        color: AppTheme.statusWarning,
        label: 'لم يُنشر منذ ${age.inDays} أيام — تحقق من جدولة GitHub Actions'
      );
    }

    if (latest.isRunning) {
      return (color: AppTheme.goldPrimary, label: 'جاري إنتاج ونشر ريل الآن...');
    }

    return (
      color: AppTheme.statusError,
      label: 'فشلت آخر عملية نشر — راجع السجل بالأسفل'
    );
  }

  Widget _buildStatusCard(String repoUrl) {
    final health = _channelHealth();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: health.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: health.color,
                  boxShadow: [
                    BoxShadow(color: health.color.withValues(alpha: 0.5), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  health.label,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: health.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'المستودع: $_githubUser/$_githubRepo',
            style: GoogleFonts.cairo(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _openUrl(repoUrl),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.open_in_new_rounded, size: 14, color: AppTheme.goldLight),
                const SizedBox(width: 6),
                Text(
                  'فتح المستودع وسجلات النشر على GitHub',
                  style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.goldLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الفيديو القادم خلال:',
                style: GoogleFonts.cairo(fontSize: 14, color: AppTheme.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.goldPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDuration(_timeUntilNextRun),
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.goldLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'مواعيد النشر اليومية (4 مرات):',
            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          _buildScheduleItem('🌙 ثلث الليل المتأخر (~3:22 AM)', 'أوقات استجابة الدعاء'),
          _buildScheduleItem('🌅 الصباح والضحى (~8:41 AM)', 'بداية اليوم والبركة'),
          _buildScheduleItem('☀️ الظهيرة (~2:33 PM)', 'استراحة العمل والذكر'),
          _buildScheduleItem('✨ المساء وذروة التفاعل (~8:19 PM)', 'أعلى تفاعل ومشاركات'),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.textSecondary)),
          Text(desc, style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildInstantTriggerButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isTriggeringRun ? null : _triggerInstantRun,
        icon: _isTriggeringRun
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bgDark),
              )
            : const Icon(Icons.bolt_rounded, color: AppTheme.bgDark),
        label: Text(
          _isTriggeringRun ? 'جاري بدء النشر السحابي...' : '⚡ نشر ريل قرآني جديد الآن فوراً',
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.bgDark),
        ),
      ),
    );
  }

  Widget _buildRunsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سجل عمليات النشر الأخيرة:',
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.goldLight),
        ),
        const SizedBox(height: 12),
        if (_recentRuns.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'لا توجد سجلات بعد أو جاري تجهيز أول فيديو...',
              style: GoogleFonts.cairo(color: AppTheme.textMuted, fontSize: 13),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentRuns.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final run = _recentRuns[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: run.isSuccess
                        ? AppTheme.statusSuccess.withValues(alpha: 0.3)
                        : run.isRunning
                            ? AppTheme.goldPrimary.withValues(alpha: 0.3)
                            : AppTheme.statusError.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      run.isSuccess
                          ? Icons.check_circle_rounded
                          : run.isRunning
                              ? Icons.hourglass_top_rounded
                              : Icons.error_outline_rounded,
                      color: run.isSuccess
                          ? AppTheme.statusSuccess
                          : run.isRunning
                              ? AppTheme.goldPrimary
                              : AppTheme.statusError,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            run.isSuccess
                                ? 'تم النشر بنجاح على يوتيوب ✅'
                                : run.isRunning
                                    ? 'جاري الرندر والرفع الآن ⏳'
                                    : 'فشل العملية',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            DateFormat('yyyy-MM-dd – hh:mm a').format(run.createdAt.toLocal()),
                            style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.launch_rounded, size: 18, color: AppTheme.goldLight),
                      onPressed: () => _openUrl(run.htmlUrl),
                      tooltip: 'عرض السجل',
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDashboardFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_rounded, color: AppTheme.goldLight, size: 16),
              const SizedBox(width: 8),
              Text(
                'فكرة وتطوير: ${AppConstants.authorName}',
                style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.goldLight),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'صاحب ${AppConstants.channelName} — صدقة جارية لوجه الله',
            style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openUrl(AppConstants.channelUrl),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.subscriptions_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'اشترك في قناة المطور',
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openUrl(AppConstants.tutorialVideoUrl),
                  icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.goldLight, size: 16),
                  label: Text(
                    'فيديو الشرح',
                    style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.goldLight, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.goldPrimary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
