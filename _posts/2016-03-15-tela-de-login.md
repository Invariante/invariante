---
layout: post
title: Tela de login
---

> **Nota do autor:** Estou começando um projeto novo e nele vou tentar usar o máximo sobre `RxSwift` que eu conseguir. E vou compartilhar grande parte dessa caminhada aqui no Invariante.

Todos nós já estivemos nessa situação: projeto novo, aplicativo novo. E, invariantemente: uma tela de login.

E muitas vezes é nesse momento que nos questionamos sobre as decisões mais básicas em relação a arquitetura e organização do código que vamos construir a partir desse momento. Se pararmos para pensar, a tela de login agrega e unifica várias faces do desenvolvimento de software: conexão com uma API, armazenamento (seguro) de informações do usuário, validação de dados, interação com o usuário e até bons cenários de testes.

E por isso é sempre uma ótima oportunidade para tentarmos, testarmos - e muitas vezes aprender - coisas novas. Eu acredito que uma tela de login oferece desafios para desenvolvedores de **todos** os níveis de experiência.


## A tela de login

Nome de usuário, senha e um botão.

O cenário não poderia ser mais ideal para exercitarmos o uso de _bindings_. A idéia é simples: queremos habilitar o botão se os campos de nome de usuário e senha forem válidos. Por enquanto, vamos supor que ambos os campos são válidos se tiverem pelo menos um caractere.

Nenhuma novidade por aqui. Apenas por clareza, esses são nossos `IBOutlets`:

~~~ swift
@IBOutlet private weak var usernameTextField: LoginTextField!
@IBOutlet private weak var passwordTextField: LoginTextField!
@IBOutlet private weak var loginButton: UIButton!
~~~

E, como em qualquer mundo, vamos definir as nossas duas funções de validação:

~~~ swift
func validateUsername(username: String) -> Bool {
    return username.characters.count > 0
}
    
func validatePassword(password: String) -> Bool {
    return password.characters.count > 0
}
~~~

E agora, vamos fazer nosso binding:

~~~swift
let validUsername = usernameTextField.rx_text.map(validateUsername)
let validPassword = passwordTextField.rx_text.map(validatePassword)
[validUsername, validPassword]
    .combineLatest { $0.first! && $0.last! }
    .bindTo(loginButton.rx_enabled)
    .addDisposableTo(disposeBag)
~~~
            
É exatamente isso: essas 6 linhas de código resolvem o nosso problema.

> Se você não tem idéia do que o código acima signfica, recomendo [ler o meu post sobre RxSwift no equinocios.com](http://equinocios.com/2016/03/14/rxswift-como-eu-vim-parar-aqui/).
 
Primeiramente, é importante saber que existe uma extensão do `RxSwift` chamada `RxCocoa` que aplica os conceitos do `RxSwift` em várias  classes do `Cocoa`/`UIKit`. É através do `RxCocoa` que conseguimos fazer os _bindings_.

No código acima, fazemos um `map` em cima do `rx_text` (que nada mais é do que o _stream_ de strings do `UITextField`. Lembre-se: no `RxSwift` tudo são _streams_). E as funções que utilizamos para fazer o `map`, nada mais são do que as nossas funções de validação declaradas mais acima.

Com isso, nossas variáveis `validUsername` e `validPassoword` são do tipo `Observable<Bool>` e não `Bool`, o que nos permite usar o operador `combineLatest`, que emitirá um _array_ com dois `Bool`, toda vez que um dos _streams_ `validUsername` **ou** `validPassword` emitirem um valor. E esses dois _streams_ por sua vez emitiram valores quando houver alguma mudança no `usernameTextField` e `passwordTextField` respectivamente.

O nosso `combineLatest` nada mais faz do que um `&&` entre o primeiro e o último elemento do nosso array. Aqui usamos um _force unwrap_ (é, eu sei: dói até de ver) porque sabemos que nosso _array_ terá **sempre** dois elementos.

E agora? Qual o tipo do resultado do resultado do nosso `combineLatest`?  Se você pensou `Observable<Bool>`, você já está pensando de uma maneira mais zen ☮️.

Por último (ou quase último), fazemos o **bind** desse resultado com o valor `rx_enabled` do nosso `loginButton`. Ou seja, toda vez que o resultado do `combineLatest` for `true`, nosso botão irá passar para o estado ativo. E toda vez que o resultado for `false`, nosso botão ficará inativo.

Por último (de verdade), temos o `addDisposableTo`. Essa é a forma que o RxSwift gerencia a memória e os recursos alocados. Se você quiser saber mais sobre as `DisposeBags`, recomento ler o [Getting Started do `RxSwift`](https://github.com/ReactiveX/RxSwift/blob/master/Documentation/GettingStarted.md#disposing). 

---

No próximo artigo, vamos trabalhar em cima de outro conceito simples, mas com uma abordagem funcional: vamos fazer com que a ação do nosso botão de login dispare a requisição de autenticação para a nossa 
API.

Bruno Koga <br />
[@brunokoga](http://twitter.com/brunokoga)
