import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/sentinel_search_models.dart';

class SearchTab extends StatelessWidget {
  final TextEditingController startDateController;
  final TextEditingController endDateController;
  final TextEditingController cloudCoverController;
  final TextEditingController geoJsonController;
  final Set<SatelliteDataType> selectedDataTypes;
  final DateTime startDate;
  final DateTime endDate;
  final String? loadedFileName;
  final bool isFileLoaded;
  final bool isUploading;
  final bool isPolygonMode;
  final int polygonPointsCount;
  final bool hasValidPolygon;

  final Function(SatelliteDataType) onDataTypeChanged;
  final Function(bool) onSelectDate;
  final VoidCallback onImportZipFile;
  final VoidCallback onTogglePolygonMode;
  final VoidCallback onClearPolygonPoints;
  final VoidCallback onUsePolygonAsGeoJson;
  final VoidCallback onSearch;

  const SearchTab({
    super.key,
    required this.startDateController,
    required this.endDateController,
    required this.cloudCoverController,
    required this.geoJsonController,
    required this.selectedDataTypes,
    required this.startDate,
    required this.endDate,
    required this.loadedFileName,
    required this.isFileLoaded,
    required this.isUploading,
    required this.isPolygonMode,
    required this.polygonPointsCount,
    required this.hasValidPolygon,
    required this.onDataTypeChanged,
    required this.onSelectDate,
    required this.onImportZipFile,
    required this.onTogglePolygonMode,
    required this.onClearPolygonPoints,
    required this.onUsePolygonAsGeoJson,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDataTypeSection(),
          const SizedBox(height: 12),
          _buildDateSection(),
          const SizedBox(height: 12),
          _buildCloudCoverSection(),
          const SizedBox(height: 12),
          _buildGeoJsonSection(),
          const SizedBox(height: 16),
          _buildSearchButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDataTypeSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.satellite_alt, color: Colors.blue, size: 16),
              SizedBox(width: 6),
              Text(
                '数据类型',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SatelliteDataType.values.map((dataType) {
              final isSelected = selectedDataTypes.contains(dataType);
              return InkWell(
                onTap: () => onDataTypeChanged(dataType),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    dataType.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            '* 目前支持单选,未来将支持多选',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.blue, size: 16),
              SizedBox(width: 6),
              Text(
                '时间范围',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDateField('开始', startDateController, () => onSelectDate(true)),
              ),
              const SizedBox(width: 8),
              const Text('至', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDateField('结束', endDateController, () => onSelectDate(false)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCloudCoverSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud, color: Colors.blue, size: 16),
              SizedBox(width: 6),
              Text(
                '云量过滤',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: TextFormField(
              controller: cloudCoverController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: '最大云量(%)',
                hintText: '0-100',
                prefixIcon: const Icon(Icons.cloud_outlined, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeoJsonSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '搜索范围',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              _buildStatusIndicator(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '支持导入shp文件的压缩包 or 点击地图绘制',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          _buildActionButtons(),
          if (isPolygonMode || polygonPointsCount > 0) _buildPolygonStatus(),
          if (isFileLoaded && loadedFileName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.attachment, size: 12, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '当前区域: $loadedFileName',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isUploading) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '正在上传文件...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (isFileLoaded && loadedFileName != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 10, color: Colors.green.shade700),
            const SizedBox(width: 3),
            Text(
              '已导入文件',
              style: TextStyle(
                fontSize: 9,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (hasValidPolygon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_location, size: 10, color: Colors.blue.shade700),
            const SizedBox(width: 3),
            Text(
              '已绘制区域',
              style: TextStyle(
                fontSize: 9,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (isPolygonMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              '绘制中',
              style: TextStyle(
                fontSize: 9,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: isUploading ? Icons.hourglass_empty : Icons.file_upload,
                label: isUploading ? '上传中...' : '导入压缩包',
                color: Colors.green,
                onTap: isUploading ? null : onImportZipFile,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: isPolygonMode ? Icons.stop : Icons.edit_location,
                label: isPolygonMode ? '停止绘制' : '地图绘制',
                color: isPolygonMode ? Colors.red : Colors.purple,
                onTap: () {
                  if (!isPolygonMode && polygonPointsCount > 0) {
                    onClearPolygonPoints();
                  }
                  onTogglePolygonMode();
                },
              ),
            ),
            if (polygonPointsCount > 0) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.refresh,
                  label: '清除点',
                  color: Colors.orange,
                  onTap: onClearPolygonPoints,
                ),
              ),
            ],
            if (hasValidPolygon) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.check,
                  label: '使用区域',
                  color: Colors.teal,
                  onTap: onUsePolygonAsGeoJson,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPolygonStatus() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isPolygonMode ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPolygonMode ? Colors.orange.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPolygonMode ? Icons.touch_app : Icons.check_circle,
                size: 14,
                color: isPolygonMode ? Colors.orange.shade700 : Colors.blue.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                isPolygonMode ? '地图绘制模式' : '已绘制区域',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPolygonMode ? Colors.orange.shade700 : Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPolygonMode ? Colors.orange.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$polygonPointsCount 个点',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isPolygonMode ? Colors.orange.shade800 : Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isPolygonMode
                ? '点击地图添加点,3个点以上可形成搜索区域'
                : hasValidPolygon
                ? '点击"使用区域"将绘制的多边形设为搜索范围'
                : '需要至少3个点才能形成有效搜索区域',
            style: TextStyle(
              fontSize: 10,
              color: isPolygonMode ? Colors.orange.shade600 : Colors.blue.shade600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.shade200 : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDisabled ? Colors.grey.shade300 : color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isDisabled ? Colors.grey : color, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isDisabled ? Colors.grey : color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                controller.text,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: onSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 18),
            SizedBox(width: 6),
            Text('开始搜索', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}