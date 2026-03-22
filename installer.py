import os
import sys
import time
import zipfile
import shutil
import subprocess

# --- КОНСТАНТЫ ---
APP_NAME = "MFT (Manager Files Terminal)"
INST_VERSION = "v1"
DEFAULT_PATH = "/usr/local/bin/mft"

def clear_screen():
    os.system('clear' if os.name == 'posix' else 'cls')

def show_logs(logs):
    print("\n--- ЛОГ ОТЛАДКИ ---")
    for line in logs:
        print(line)
    print("-------------------\n")

def show_final_step(success, logs):
    print(f"\n========================================")
    status = "УСПЕШНО" if success else "С ОШИБКАМИ"
    print(f"   ПРОЦЕСС ЗАВЕРШЕН {status}!")
    print(f"========================================\n")

    if input("Показать лог отладки? (y/n): ").lower() == 'y':
        show_logs(logs)

    print("ЧТО ДАЛЬШЕ?")
    print("1. Выйти")
    print("2. Начать заново (В начало)")
    
    if input("\nВаш выбор: ") == '2':
        main()
    else:
        sys.exit()

def run_installation(target_path, version="v1"):
    logs = []
    clear_screen()
    
    # СРАЗУ определяем папку, чтобы не было ошибки в логах
    target_dir = os.path.dirname(target_path)
    
    print(f"--- Установка MFT {version} ---")
    
    make_alias = input("Создать alias в .bashrc? (y/n): ").lower()
    if input(f"Начать установку {version} в {target_path}? (y/n): ").lower() != 'y':
        return

    try:
        # 1. Поиск исходного файла
        source_dir = os.path.join("mft_binaries", version)
        source_file = os.path.join(source_dir, "mft")
        
        logs.append(f"[DEBUG] Проверка источника: {source_file}")
        if not os.path.exists(source_file):
            raise FileNotFoundError(f"Файл 'mft' не найден в {source_dir}")

        # 2. Анимация (для красоты)
        for i in range(11):
            time.sleep(0.1)
            sys.stdout.write(f"\rУстановка: [{'#'*i}{'.'*(10-i)}] {i*10}%")
            sys.stdout.flush()
        print()

        # 3. Копирование (Универсальный метод)
        logs.append(f"[DEBUG] Подготовка папки: {target_dir}")
        
        # Проверяем, есть ли sudo в системе вообще
        has_sudo = shutil.which("sudo") is not None
        logs.append(f"[DEBUG] Наличие sudo: {has_sudo}")

        def run_cmd(cmd):
            # Если sudo есть, добавляем его, если нет — пускаем как есть
            final_cmd = f"sudo {cmd}" if has_sudo else cmd
            return subprocess.run(final_cmd, shell=True, check=True, capture_output=True)

        try:
            run_cmd(f"mkdir -p {target_dir}")
            logs.append(f"[DEBUG] Папка готова")

            run_cmd(f"cp {source_file} {target_path}")
            logs.append(f"[DEBUG] Файл скопирован")

            run_cmd(f"chmod +x {target_path}")
            logs.append("[DEBUG] Права +x установлены")
            
        except subprocess.CalledProcessError as e:
            logs.append(f"[ERROR] Ошибка команды: {e.stderr.decode().strip()}")
            raise

        # 4. Alias
        if make_alias == 'y':
            bashrc = os.path.expanduser("~/.bashrc")
            # Проверяем, нет ли уже такого алиаса, чтобы не дублировать
            with open(bashrc, "r") as f:
                if f"alias mft=" not in f.read():
                    with open(bashrc, "a") as fa:
                        fa.write(f"\nalias mft='sudo {target_path}'\n")
                    logs.append("[DEBUG] Alias добавлен")
                else:
                    logs.append("[DEBUG] Alias уже существует, пропускаем")

        show_final_step(True, logs)

    except Exception as e:
        logs.append(f"[ERROR] Критическая ошибка: {str(e)}")
        show_final_step(False, logs)

def recovery_menu(target_path):
    clear_screen()
    print("--- МЕНЮ ВОССТАНОВЛЕНИЯ ---")
    print("1. Удалить программу")
    print("2. Переустановить последнюю версию")
    print("3. Выбрать другую версию (v1, v2...)")
    print("4. Назад")
    
    choice = input("\nВыбор: ")
    if choice == '1':
        path = input(f"Путь для удаления ({target_path}): ") or target_path
        if os.path.exists(path):
            # subprocess.run(['sudo', 'rm', path])
            print(f"Файл {path} удален.")
        else:
            print("Файл не найден.")
        input("Нажмите Enter...")
        main()
    elif choice == '2':
        run_installation(target_path, "v1")
    elif choice == '3':
        # --- ВЫБОР ДРУГОЙ ВЕРСИИ ИЗ ПАПОК ---
        try:
            base_dir = "mft_binaries"
            if not os.path.exists(base_dir):
                raise FileNotFoundError(f"Папка {base_dir} не найдена!")

            # Получаем список всех подпапок (v1, v2...)
            versions = [d for d in os.listdir(base_dir) if os.path.isdir(os.path.join(base_dir, d))]
            versions.sort() # Чтобы v1 была первой
            
            if not versions:
                print("\n[ОШИБКА] В папке mft_binaries нет подпапок с версиями!")
                input("Нажмите Enter...")
                return recovery_menu(target_path)

            print("\nДоступные версии в системе:")
            for i, v in enumerate(versions, 1):
                print(f"{i}. {v}")
            
            v_idx = int(input("\nВыберите номер версии: ")) - 1
            selected_version = versions[v_idx]
            
            print(f"[OK] Выбрана {selected_version}. Переходим к установке...")
            run_installation(target_path, version=selected_version)

        except Exception as e:
            print(f"[ERROR] Не удалось прочитать папки версий: {e}")
            input("\nНажмите Enter...")
            main()

def main():
    clear_screen()
    print(f"========================================")
    print(f"   {APP_NAME} Installer {INST_VERSION}")
    print(f"   Автор: ZuteroG | zuterog@gmail.com")
    print(f"========================================\n")

    # ШАГ 1: Путь
    path = input(f"Куда установить? (Default: {DEFAULT_PATH}): ") or DEFAULT_PATH
    
    # ШАГ 2: Лицензия
    print("\n--- ЛИЦЕНЗИЯ ---")
    print("Автор не несет ответственности за баги после ваших модификаций.")
    if input("Согласны? (y/n): ").lower() != 'y': sys.exit()

    # ШАГ 3: Выбор режима
    print("\n1. Установка\n2. Восстановление/Удаление")
    if input("Вариант: ") == '2':
        recovery_menu(path)
    else:
        run_installation(path)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nПроцесс прерван.")