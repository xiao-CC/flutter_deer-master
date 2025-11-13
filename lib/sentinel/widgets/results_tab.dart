import 'package:flutter/material.dart';

import '../models/sentinel_search_models.dart';

class ResultsTab extends StatelessWidget {
  final bool isLoading;
  final List<SentinelSearchResult> searchResults;
  final Set<String> visibleImages;
  final Function(SentinelSearchResult, int) onToggleImage;
  final VoidCallback onClosePanel;
  final VoidCallback onSwitchToSearch;

  const ResultsTab({
    super.key,
    required this.isLoading,
    required this.searchResults,
    required this.visibleImages,
    required this.onToggleImage,
    required this.onClosePanel,
    required this.onSwitchToSearch,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('正在搜索影像数据...', style: TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              '暂无搜索结果',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '请设置搜索条件并点击搜索',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onSwitchToSearch,
              icon: const Icon(Icons.search, size: 16),
              label: const Text('去搜索', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      physics: const ClampingScrollPhysics(),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        if (index < 0 || index >= searchResults.length) {
          return const SizedBox.shrink();
        }

        final result = searchResults[index];
        final isVisible = visibleImages.contains(result.imageId);

        return _buildResultItem(result, index, isVisible);
      },
    );
  }

  Widget _buildResultItem(SentinelSearchResult result, int index, bool isVisible) {
    final cloudLevel = result.cloudCoverLevel;
    Color cloudColor;
    Color cloudBgColor;

    switch (cloudLevel) {
      case CloudCoverLevel.high:
        cloudColor = Colors.red;
        cloudBgColor = Colors.red.withOpacity(0.1);
        break;
      case CloudCoverLevel.medium:
        cloudColor = Colors.orange;
        cloudBgColor = Colors.orange.withOpacity(0.1);
        break;
      case CloudCoverLevel.low:
        cloudColor = Colors.green;
        cloudBgColor = Colors.green.withOpacity(0.1);
        break;
      case CloudCoverLevel.unknown:
        cloudColor = Colors.grey;
        cloudBgColor = Colors.grey.withOpacity(0.1);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isVisible ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isVisible ? Colors.blue : Colors.grey.shade200,
          width: isVisible ? 1.5 : 1,
        ),
        boxShadow: isVisible
            ? [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
            : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: InkWell(
        onTap: () {
          onToggleImage(result, index);
          if (!isVisible) {
            Future.delayed(const Duration(milliseconds: 500), () {
              onClosePanel();
            });
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.imageId,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isVisible ? Colors.blue.shade700 : Colors.blue,
                            fontSize: 10,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            result.satelliteTypeName,
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isVisible ? Colors.blue.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isVisible ? Icons.visibility : Icons.visibility_off,
                      color: isVisible ? Colors.blue : Colors.grey,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 3),
                      Text(
                        result.captureDate,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (result.cloudCover != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cloudBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud, size: 10, color: cloudColor),
                          const SizedBox(width: 2),
                          Text(
                            '${result.cloudCover!.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: cloudColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: const Border(
                    left: BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 10, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '平台: ${result.platform} | 星座: ${result.constellation}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 9,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}