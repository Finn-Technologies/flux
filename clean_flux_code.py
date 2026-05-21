import re
import sys

def clean():
    with open('lib/features/chat/chat_screen.dart', 'r') as f:
        content = f.read()

    # 1. Remove imports
    content = re.sub(r"import '../../core/models/flux_code_project\.dart';\n", '', content)
    content = re.sub(r"import '../../core/providers/flux_code_project_provider\.dart';\n", '', content)
    content = re.sub(r"import '../../core/services/flux_code_agent\.dart';\n", '', content)
    content = re.sub(r"import '../flux_code/flux_code_widgets\.dart';\n", '', content)
    
    # 2. Remove isFluxCode checks from build() method
    # It looks like:
    # final appMode = ref.watch(appModeProvider);
    # final isFluxCode = appMode == AppMode.fluxCode;
    # ...
    # if (isFluxCode && context.isDesktop) {
    #   return _buildFluxCodeBody(context);
    # }
    
    content = re.sub(
        r"    final appMode = ref\.watch\(appModeProvider\);\n    final isFluxCode = appMode == AppMode\.fluxCode;\n\n    if \(isFluxCode && context\.isDesktop\) \{\n      return _buildFluxCodeBody\(context\);\n    \}\n",
        "",
        content
    )

    # 3. Remove all code from _pickFluxCodeProject to _buildEmptyState
    # Let's find the indices.
    start_idx = content.find("  Future<void> _pickFluxCodeProject()")
    end_idx = content.find("  Widget _buildEmptyState(BuildContext context) {")
    
    if start_idx != -1 and end_idx != -1:
        content = content[:start_idx] + content[end_idx:]

    with open('lib/features/chat/chat_screen.dart', 'w') as f:
        f.write(content)

if __name__ == '__main__':
    clean()
