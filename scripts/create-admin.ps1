# Tạo tài khoản super admin đầu tiên cho web admin (không có trang tự đăng ký).
# Yêu cầu migrations đến 011. Chức năng mời admin chưa kết nối backend.
#
#   ./scripts/create-admin.ps1 -Email lan@trackchildren.vn -FullName "Lan Nguyễn"
#
# Mật khẩu được hash bcrypt bằng pgcrypto (crypt + gen_salt('bf')), tương thích
# và được backend nâng lên Argon2 sau lần đăng nhập thành công đầu tiên.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Email,
    [Parameter(Mandatory)] [string]$FullName,
    [securestring]$Password,
    [string]$Container = "track-children-postgres",
    [string]$Database = "track_children"
)

$ErrorActionPreference = "Stop"

if (-not $Password) {
    $Password = Read-Host "Mật khẩu (tối thiểu 10 ký tự)" -AsSecureString
}
$passwordBuffer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordBuffer)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordBuffer)
}
if ($plain.Length -lt 10 -or $plain -cnotmatch '[A-Za-z]' -or $plain -notmatch '[0-9]') {
    throw "Mật khẩu cần tối thiểu 10 ký tự, gồm chữ và số."
}
if ([Text.Encoding]::UTF8.GetByteCount($plain) -gt 72) {
    throw "Mật khẩu bootstrap bcrypt không được vượt quá 72 byte UTF-8."
}

# Truyền giá trị qua biến psql (:'name') để không phải tự escape chuỗi SQL.
$sql = @'
BEGIN;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM admin.roles WHERE code = 'super_admin') THEN
    RAISE EXCEPTION 'Missing super_admin role: apply migrations through 011 first';
  END IF;
END $$;
WITH new_admin AS (
  INSERT INTO admin.admin_users (email, password_hash, full_name)
  VALUES (:'email', crypt(:'password', gen_salt('bf', 12)), :'full_name')
  RETURNING id
)
INSERT INTO admin.admin_user_roles (admin_user_id, role_id)
SELECT new_admin.id, r.id FROM new_admin, admin.roles r WHERE r.code = 'super_admin';
COMMIT;
'@

$sql | & docker exec -i $Container psql -v ON_ERROR_STOP=1 -q -U track_children -d $Database `
    -v "email=$Email" -v "full_name=$FullName" -v "password=$plain"
if ($LASTEXITCODE -ne 0) {
    throw "Không tạo được admin (email đã tồn tại hoặc chưa chạy migration 011?)."
}
Write-Host "Đã tạo super admin $Email."
