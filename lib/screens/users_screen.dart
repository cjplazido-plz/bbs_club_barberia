void _showEditDialog(Map<String, dynamic> user) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final nameController = TextEditingController(text: user['full_name'] ?? '');
  final phoneController = TextEditingController(text: user['phone'] ?? '');
  final emailController = TextEditingController(text: user['email'] ?? '');
  final commissionController = TextEditingController(
    text: (user['commission_rate'] ?? 0).toString(),
  );
  String selectedRole = user['role'] ?? 'admin';

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Editar Usuario',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Email
            TextField(
              controller: emailController,
              enabled: false, // Email no editable
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            // Nombre
            TextField(
              controller: nameController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Nombre completo *',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Teléfono
            TextField(
              controller: phoneController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Teléfono',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Rol
            DropdownButtonFormField<String>(
              value: selectedRole,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Rol',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[300]!),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                DropdownMenuItem(value: 'cashier', child: Text('Cajero')),
                DropdownMenuItem(value: 'barber', child: Text('Barbero')),
              ],
              onChanged: (value) {
                if (value != null) selectedRole = value;
              },
            ),
            const SizedBox(height: 12),
            // Comisión
            TextField(
              controller: commissionController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: '% Comisión (barberos)',
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: () async {
            // Lógica de guardado...
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
          ),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}