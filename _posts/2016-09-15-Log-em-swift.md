---
layout:     post
title:      "Logs em Swift"
---

---

Depois de quase 5 meses estamos de volta, 🖖.

---

Todo mundo, uma hora ou outra, coloca uns `NSLog`s no código e muitas vezes esse log é útil apenas para o desenvolvimento ou *debug*. Então não é uma boa idéia usar direto o `NSLog` ou o `print` do `Swift`.

Em `Objective-C` eu tenho duas macros que escrevi faz muitos anos e funcionam muito bem:

~~~ objc

#ifdef DEBUG
    #define DTLog(fmt, ...) NSLog((@"%s:%d %s : " fmt), __FILE__, __LINE__, __PRETTY_FUNCTION__, ##__VA_ARGS__)
#else
    #define DTLog NSLog
#endif

#ifdef DEBUG
    #define DTLogD(fmt, ...) NSLog((@"%s:%d %s : " fmt), __FILE__, __LINE__, __PRETTY_FUNCTION__, ##__VA_ARGS__)
#else
    #define DTLogD(...)
#endif

~~~

O que eu gosto delas é que quando o programa roda em *debug*, além da mensagem são apresentados o nome do arquivo `__FILE__`, a linha `__LINE__` e o nome da função `__PRETTY_FUNCTION__` em que elas foram chamadas. Além disso em *release* uma delas não mostra nada.

Note que essas são macros do pré-processador de C, isso significa que são avaliadas antes do código ser compilado e que seu comportamento depende da macro *DEBUG* estar definida. Quando criamos um projeto o Xcode já define essa macro para nós:

![Xcode precompiler macros](/public/imgs/log-01.png)

Então se você copia-las para seu projeto tudo já vai estar funcionando!

Em `Swift` as coisas mudam um pouco, não temos macros do pré-processador. Mas o equivalente direto seriam funções globais, o que não tem muito cara de `Swift`. O que tenho usado[^1] é um `struct`  com duas funções estáticas:

[^1]: Já em `Swift` 3.0

~~~ swift
public struct Log {

    public static func info(
        _ items: Any...,
        functionName: String = #function,
        fileName: String = #file,
        lineNumber: Int = #line)
    {
        log(items,
            functionName: functionName,
            fileName: fileName,
            lineNumber: lineNumber)
    }

    public static func debug(
        _ items: Any...,
        functionName: String = #function,
        fileName: String = #file,
        lineNumber: Int = #line)
    {
        #if DEBUG
            log(items,
                functionName: functionName,
                fileName: fileName,
                lineNumber: lineNumber)
        #endif
    }

    private static func log(
        _ items: [Any],
        functionName: String,
        fileName: String,
        lineNumber: Int)
    {
        let url = NSURL(fileURLWithPath: fileName)
        let lastPathComponent = url.lastPathComponent ?? fileName
        #if DEBUG
            print("[\(lastPathComponent):\(lineNumber)] \(functionName):",
                separator: "",
                terminator: " ")
        #endif
        for item in items {
            print(item, separator: "", terminator: "")
        }
        print("")
    }

}
~~~

Apesar de `Swift` não ter macros, temos as *[Special Literal Expressions](https://developer.apple.com/library/content/documentation/Swift/Conceptual/Swift_Programming_Language/Expressions.html#//apple_ref/doc/uid/TP40014097-CH32-ID389)* `#file`, `#line` e `#function` que têm praticamente o mesmo comportamento. Juntando com um pouco de malabarismo com [Variadic Parameters](https://developer.apple.com/library/content/documentation/Swift/Conceptual/Swift_Programming_Language/Functions.html#//apple_ref/doc/uid/TP40014097-CH10-ID166) fica até mais elegante que as macros.
Mas se você copiar e colar esse código no seu projeto provavelmente ele não vai funcionar direito, isso por conta do `#if DEBUG`. Isso não é uma macro, é um *[Conditional Compilation Blocks](https://developer.apple.com/library/content/documentation/Swift/Conceptual/BuildingCocoaApps/InteractingWithCAPIs.html#//apple_ref/doc/uid/TP40014216-CH8-ID31)* e o *Xcode* não cria automaticamente um `DEBUG` para você 😔. Mas não tem problema, é só adicionar no *Build Settings* do projeto:

![Xcode swift custom flags](/public/imgs/log-02.png)

Note que diferente da macro não é atribuido um valor e a *flag* é precedida de `-D`.

---

Criticas, sugestões e comentários são sempre bem-vindos, é só me *pingar* no [@diogot](https://twitter.com/diogot) ou no [Slack do iOS Dev BR](http://iosdevbr.herokuapp.com).

---
Diogo Tridapalli <br />
[@diogot](https://twitter.com/diogot)

---
