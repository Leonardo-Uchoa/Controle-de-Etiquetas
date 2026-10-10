# Controle de Etiquetas (Flutter)

Aplicativo offline para Android. Cada código de produto possui uma única data de validade.

## Requisitos
- Flutter SDK e Android SDK configurados.

## Como gerar o APK
1. Crie a estrutura nativa: `flutter create --platforms=android .`
2. Instale dependências: `flutter pub get`
3. Teste no Android: `flutter run`
4. Gere o APK: `flutter build apk --release`
5. Arquivo final: `build/app/outputs/flutter-apk/app-release.apk`

## Recursos
- Cadastro, edição, exclusão, busca e filtros por status.
- Dados locais com shared_preferences (persistem entre aberturas; desinstalar o app pode apagá-los).
- Verde: vencimento em dois meses ou mais (meses de calendário).
- Amarelo: vencimento futuro em menos de dois meses.
- Laranja: vence hoje.
- Vermelho: venceu antes de hoje.
- Relatório CSV de vencidos até data escolhida, compartilhável pelo Android.

## Observação
O projeto contém o código Flutter. A pasta `android/` será criada pelo comando `flutter create`, que deve ser executado em um ambiente com Flutter instalado. O APK não está incluído.

## Compilacao automatica pelo GitHub Actions
O workflow `.github/workflows/android-apk.yml` executa a compilacao em um servidor do GitHub quando arquivos sao enviados para a branch `main` ou `master`, ou manualmente na aba Actions > Gerar APK Android > Run workflow.
Apos a execucao com sucesso, abra a execucao e baixe o artifact `controle-etiquetas-apk` (ZIP que contem `app-release.apk`). Extraia o ZIP no celular e instale o APK. A compilacao ainda precisa ser executada no GitHub; este pacote nao contem APK.
